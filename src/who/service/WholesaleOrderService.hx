package who.service;
import who.db.WConfig;

/**
 *  Wholesale order service
 */
class WholesaleOrderService {

	public var contract:db.Contract;
	public var conf:who.db.WConfig;

	public function new(contract:db.Contract){
		this.contract = contract;
		this.conf = WConfig.getOrCreate(contract);
	}

	public function enable(){
		conf.lock();
		conf.active = true;
		conf.update();
	}

	public static function linksAsMap(arr:Array<{p1:db.Product,p2:db.Product}>){
		
		var retailToWholesale = new Map();
		for ( l in arr) retailToWholesale[l.p1.id] = l.p2;
		return retailToWholesale;
	}

	/**
	 *  get distributions that can be balanced
	 */
	public function getDistributions(){
		if(!conf.active) return [];
		var now = Date.now();
		return Lambda.array(db.Distribution.manager.search($contract==this.contract && $orderEndDate < now && $date > now,false));
	}
	
	/**
	 * get links on the fly
	 * 
	 * @param excludeIdenticalProducts	Exclude links between 2 same products
	 */
	public function getLinks(?excludeIdenticalProducts = false ){

		if(!conf.active) return [];
		
		var rc = connector.db.RemoteCatalog.getFromContract(contract);
		if (rc == null) return [];

		//populate a map by productId containing related offers
		var catOffers = new Map<Int,Array<pro.db.POffer>>(); 
		for( o in rc.getCatalog().getOffers()){
			var x = catOffers[o.offer.product.id];
			if(x==null) x = [];
			x.push(o.offer);
			catOffers[o.offer.product.id] = x;
		}
		
		var out = [];
		
		for (offers in catOffers ){
			
			while(offers.length>1){
				var bigOffer = getOfferWithHighestQuantity(offers);
				var littleOffer = getOfferWithLowestQuantity(offers);
				offers.remove(littleOffer);
			
				var little = db.Product.getByRef(contract,littleOffer.ref);
				var big = db.Product.getByRef(contract,bigOffer.ref);
				if (little == null) throw new tink.core.Error("unable to find detail product with ref "+littleOffer.ref);
				if (big == null) throw new tink.core.Error("unable to find wholesale product with ref "+bigOffer.ref);

				//big products should have floatQt enabled ! Otherwise editing an order will round quantities
				if (!bigOffer.product.hasFloatQt){
					bigOffer.product.lock();
					bigOffer.product.hasFloatQt = true;
					bigOffer.product.update();
					var cat = rc.getCatalog();
					cat.toSync();
				}
			
				out.push({p1:little,p2:big});
			}
		}

		return out;
	}

	function getOfferWithLowestQuantity(offers:Array<pro.db.POffer>):pro.db.POffer{
		var out : pro.db.POffer = null;
		for( o in offers){
			if(out==null || out.quantity>o.quantity) out = o; 
		}
		return out;
	}

	function getOfferWithHighestQuantity(offers:Array<pro.db.POffer>):pro.db.POffer{
		var out : pro.db.POffer = null;
		for( o in offers){
			if(out==null || out.quantity<o.quantity) out = o; 
		}
		return out;
	}


	/**
	 * Moves the distribution to the wholesale contract + update orders to wholesale products
	 */
	public function confirm(d:db.Distribution){
		
		/*
		var links = getLinks(d.contract, conf.contract2);
		
		//check same group ?
		if ( conf.contract1.amap.id != conf.contract2.amap.id){
			throw "Les deux contrats ne font pas partie du même groupe.";
		}
		
		var retailToWholesale = linksAsMap(links);
		
		var c1 = d.contract;
		var c2 = conf.contract2;
		
		//moves distrib
		d.lock();
		d.contract = c2;
		d.update();
		
		//update orders
		for ( o in d.getOrders()){
			
			o.lock();
			
			if (retailToWholesale[o.product.id] == null){
				//no linkage
				continue;
			}
			
			var qt1 = o.product.qt;
			var qt2 = retailToWholesale[o.product.id].qt;
			
			//trace(o.quantity+" "+o.product.name+"<br/>");
			
			o.product = retailToWholesale[o.product.id];
			o.quantity *= (qt1 / qt2);
			o.productPrice = o.product.price;
			
			//trace("Devient "+o.quantity+" "+o.product.name+"<br/>");
			
			o.update();
			
		}
		*/
		return d;
		
		
	}


}