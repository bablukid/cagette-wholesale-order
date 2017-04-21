package who.db;
import sys.db.Object;
import sys.db.Types;
import Common;

@:id(p1Id,p2Id)
class WProductLink extends Object
{
	
	@:relation(p1Id) public var p1 : db.Product;//detail product
	@:relation(p2Id) public var p2 : db.Product;//detail product
	
	/**
	 * @deprecated
	 * @param	c
	 */
	/*public static function get(c:db.Contract){
		
		var pids = tools.ObjectListTool.getIds(c.getProducts(false));
		
		return who.db.WProductLink.manager.search($p1Id in pids, false);		
	}*/
	
	/**
	 * autolink with Cagette Pro Data and store links
	 */
	public static function autolink(c1:db.Contract,c2:db.Contract){
		var rc1 = connector.db.RemoteCatalog.getFromContract(c1);
		var c1off = rc1.getCatalog().getOffers();
		
		var rc2 = connector.db.RemoteCatalog.getFromContract(c2);
		var c2off = rc2.getCatalog().getOffers();
		
		for (off in c1off){
			
			//off is the retail product
			
			var offs = off.offer.product.getOffers();
			
			
			var big = offs.first();
			var little = off.offer;
			if ( big.id != little.id){
				
				var little = db.Product.getByRef(c1,little.ref);
				var big = db.Product.getByRef(c2,big.ref);
				
				make(little, big);
				//trace('big est $big, little est $little <br/>');
			}
		}
	}
	
	public static function linksAsMap(arr:Array<{p1:db.Product,p2:db.Product}>){
		
		var retailToWholesale = new Map();
		for ( l in arr) retailToWholesale[l.p1.id] = l.p2;
		return retailToWholesale;
	}
	
	/**
	 * get links on the fly
	 */
	public static function getLinks(c1:db.Contract,c2:db.Contract){
		var rc1 = connector.db.RemoteCatalog.getFromContract(c1);
		var c1off = rc1.getCatalog().getOffers();
		
		var rc2 = connector.db.RemoteCatalog.getFromContract(c2);
		var c2off = rc2.getCatalog().getOffers();
		
		var out = [];
		
		for (off in c1off){
			
			//off is the retail product
			
			var offs = off.offer.product.getOffers();
			
			
			var big = offs.first();
			var little = off.offer;
			//if ( big.id != little.id){
				
				var little = db.Product.getByRef(c1,little.ref);
				var big = db.Product.getByRef(c2,big.ref);
				
				out.push({p1:little,p2:big });
				//trace('big est $big, little est $little <br/>');
			//}
		}
		
		return out;
	}
	
	
	
	public static function make(p1:db.Product, p2:db.Product){
		var pl = new WProductLink();
		pl.p1 = p1;
		pl.p2 = p2;
		pl.insert();
		return pl;
		
	}
	
	/**
	 * Moves the distribution to the wholesale contract + update orders to wholesale products
	 */
	public static function confirm(d:db.Distribution){
		
		
		var conf = WConfig.getOrCreate(d.contract);
		var links = getLinks(d.contract,conf.contract2);
		
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
		
		return d;
		
		
	}
	
}

