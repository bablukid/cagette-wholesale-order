package who.service;
import who.db.WConfig;
import tink.core.Error;

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

	/**
	 *  Transforms an array of products couples to a map
	 */
	public static function linksAsMap(arr:Array<{p1:db.Product,p2:db.Product}>):Map<Int,db.Product>{
		
		var retailToWholesale = new Map();
		for (l in arr) retailToWholesale[l.p1.id] = l.p2;
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
	public function getLinks(?excludeIdenticalProducts = false ):Array<{p1:db.Product,p2:db.Product}>{

		if(!conf.active) return [];
		var out = [];
		
		var rc = connector.db.RemoteCatalog.getFromContract(contract);
		if (rc == null) return [];

		//get from cache
		var cache : Array<{p1:Int,p2:Int}> = sugoi.db.Cache.get("wholesale_links_contract"+contract.id);
		if(cache!=null){
			for( c in cache){
				out.push({
					p1:db.Product.manager.get(c.p1,false),
					p2:db.Product.manager.get(c.p2,false)
				});
			}
			return out;
		}


		//populate a map by productId containing related offers
		var catOffers = new Map<Int,Array<pro.db.POffer>>(); 
		for( o in rc.getCatalog().getOffers()){
			var x = catOffers[o.offer.product.id];
			if(x==null) x = [];
			x.push(o.offer);
			catOffers[o.offer.product.id] = x;
		}
		
		for (offers in catOffers ){
			
			while(offers.length>1){
				var bigOffer = getOfferWithHighestQuantity(offers);
				var littleOffer = getOfferWithLowestQuantity(offers);
				offers.remove(littleOffer);
			
				var little = db.Product.getByRef(contract,littleOffer.ref);
				var big = db.Product.getByRef(contract,bigOffer.ref);
				if (little == null) throw new tink.core.Error("unable to find detail product with ref "+littleOffer.ref);
				if (big == null) throw new tink.core.Error("unable to find wholesale product with ref "+bigOffer.ref);
				if(excludeIdenticalProducts && little.id==big.id) continue;

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


		//save cache
		if(cache==null){
			var cache = [];
			for(o in out) cache.push({p1:o.p1.id,p2:o.p2.id});
			sugoi.db.Cache.set("wholesale_links_contract"+contract.id,cache,60*10); //store for 10 mn
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
	 * Confirms order balancing : convert retail products orders to wholesale products orders
	 */
	public function confirm(d:db.Distribution){
		
		var links = getLinks(true);
		var retailToWholesale = linksAsMap(links);
		var orders = d.getOrders();

		//update orders
		// Sys.println("===CONFIRM===");
		for ( o in orders){
			
			o.lock();
			
			if (retailToWholesale[o.product.id] == null){
				//no change
				continue;
			}
			
			var qt1 = o.product.qt;
			var qt2 = retailToWholesale[o.product.id].qt;
			
			// Sys.println(o.user.name+" : "+o.quantity+" x "+o.product.getName()+" ");
			
			o.product = retailToWholesale[o.product.id];
			o.quantity *= (qt1 / qt2);
			o.productPrice = o.product.price;
			
			// Sys.println("devient "+o.quantity+" "+o.product.getName()+"\n");
		}

		// Sys.println("===TOTAL===");
		//for( o in orders) Sys.println(o.user.getName()+" "+o.quantity+" "+o.product.getName()+"\n");

		//check if the whole order is confirmable.
		//simulate a summary  by products		
		var check  = new Map<Int,Float>(); //product Id -> Qty
		for ( o in orders){
			
			var q = check.get(o.product.id);
			if(q==null) q = 0.0;
			q += o.quantity;
			check.set(o.product.id, q );
			
		}
		// Sys.println("===TOTAL BY PRODUCT===");
		for(k  in check.keys()){
			var v = check.get(k);
			var prod = db.Product.manager.get(k);
			// Sys.println(prod.getName()+" x "+ v );

			if(v!=Math.round(v)){
				throw new Error("Balancing not possible : qt "+v+" of "+prod.getName()+" is not integer");
			}
		}

		for( o in orders) o.update();

		sendMailToMembers(d);
		sendMailToManager(d);
		
		return d;
		
	}


	function sendMailToMembers(d:db.Distribution){
		service.OrderService.sendOrderSummaryToMembers(d);
	}


	function sendMailToManager(d:db.Distribution){
		service.OrderService.sendOrdersByProductReport(d);
	}


}