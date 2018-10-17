package who.service;
import who.db.WConfig;
import tink.core.Error;
import service.OrderService;

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

			var offers = sortOffersByQt(offers);

			//find the big offer
			var bigOffer = offers[0];
			var big = db.Product.getByRef(contract,bigOffer.ref);
			if (big == null) throw new tink.core.Error("unable to find wholesale product with ref "+bigOffer.ref);
			offers.remove(bigOffer);

			//big products should have wholesale enabled ! Otherwise editing an order will round quantities
			if (!bigOffer.product.wholesale){
				bigOffer.product.lock();
				bigOffer.product.hasFloatQt = false;
				bigOffer.product.wholesale = true;
				bigOffer.product.update();
				var cat = rc.getCatalog();
				cat.toSync();
			}
			
			for ( off in offers ){
				
				var little = db.Product.getByRef(contract,off.ref);
				if (little == null) throw new tink.core.Error("unable to find detail product with ref "+off.ref);
				if(excludeIdenticalProducts && little.id==big.id) continue;
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

	/**
		Get a summary of balancing needs
	**/
	public function getBalancingSummary(d:db.Distribution,?product:db.Product):Array<{retail:db.Product,wholesale:db.Product,totalQt:Float,relatedWholesaleOrder:Int,missing:Float}>{
		var links = getLinks(true);
		var out = [];
		var roundTo = App.current.view.roundTo;

		for( l in links ){
			if(product!=null && l.p1.id!=product.id) continue;
			var qt = totalOrder(l.p1,d) * l.p1.qt;
			out.push({
				retail : l.p1, 					//retail product
				wholesale : l.p2, 				//wholesale product
				totalQt : qt, 					//total ordered quantity of retail product
				relatedWholesaleOrder : Math.floor(roundTo(qt/l.p2.qt,2)),				//how many wholesale product it makes					
				missing : roundTo(l.p2.qt - (qt % l.p2.qt),2)	//missing quantity to reach wholesale
			});
		}
		return out;
	}

	public function totalOrder(p:db.Product,d:db.Distribution){
		var orders = db.UserContract.manager.search($distribution == d && $product == p, false);			
		var tot = 0.0;
		for ( o in orders ) tot += o.quantity;
		return tot;
	}

	public function sortOffersByQt(offers:Array<pro.db.POffer>):Array<pro.db.POffer>{
		//highest first
		offers.sort(function(x,y){
			return Math.round(y.quantity - x.quantity);
		});

		return offers;
	}



	/**
	 * Confirms order balancing : convert retail products orders to wholesale products orders
	 */
	public function confirm(d:db.Distribution){
		
		var links = getLinks(true);
		var retailToWholesale = linksAsMap(links);
		var orders = d.getOrders();
		var newOrders = [];

		//update orders
		for ( o in orders){
			
			if (retailToWholesale[o.product.id] == null){
				//no change
				continue;
			}

			var qt1 = o.product.qt;
			var qt2 = retailToWholesale[o.product.id].qt;
			var qt = o.quantity * (qt1 / qt2);
			//o.productPrice = o.product.price;

			var newOrder = OrderService.make(o.user, qt, retailToWholesale[o.product.id],d.id,null,o.user2,null);
			if(newOrder!=null){
				newOrders.push(newOrder);
				o.delete();
			}
		}

		var total = OrderService.getOrdersByProduct({distribution:d});

		for( t in total ){
			//do not check products wich are not detail products
			if ( Lambda.find(links,function(el) return el.p2.id == t.pid)==null ){
				continue;
			}
			if( !tools.FloatTool.isEqual(t.quantity , Math.round(t.quantity) ) ){
				//changes won't be commited thanks to MySQL Transactions				
				throw new Error('Balancing not possible : quantity ${t.quantity} of "${t.pname}" should be integer. ( ${t.quantity} != ${Math.round(t.quantity)} )');
			}

		}

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