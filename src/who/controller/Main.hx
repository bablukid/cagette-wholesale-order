package who.controller;


/**
 * @author fbarbut<francois.barbut@gmail.com>
 */
class Main extends controller.Controller
{

	public function new() 
	{
		super();
		
	}
	
	function init(c){
		if (!app.user.isContractManager(c)) throw "accès interdit";		
		new controller.ContractAdmin().sendNav(c);
		view.c = c;
		view.nav = ["contractadmin","who"];
	}

	@logged @tpl("plugin/who/default.mtt")
	public function doDefault(c:db.Contract){
		var conf = who.db.WConfig.getOrCreate(c);
		view.active = conf.active;
		
		init(c);
		var now = Date.now();
		view.distributions = db.Distribution.manager.search($contract==c && $orderEndDate < now && $date > now,false);
		view.links = conf.contract2==null ? [] : who.db.WProductLink.getLinks(c,conf.contract2,true);
	}
	

	@logged @tpl("plugin/who/config.mtt")
	public function doConfig(c:db.Contract){
		
		init(c);
		
		var conf = who.db.WConfig.getOrCreate(c);
		
		var f = sugoi.form.Form.fromSpod(conf);
		f.removeElementByName("contract1Id");
		f.getElement("contract2Id").label = "Contrat en gros correspondant";
		//f.getElement("delay").label = "Délai en jours";
		
		if (f.isValid()){
			f.toSpod(conf);
			conf.update();
			throw Ok("/p/who/"+c.id,"Configuration mise à jour");
		}
		
		view.form = f;
	}
	
	/**
	 * @deprecated
	 */
	@logged @tpl("plugin/who/link.mtt")
	public function doLink(c:db.Contract,?c2:db.Contract){
		/*
		init(c);
		if (c2 == null){
			
			var f = new sugoi.form.Form("contracts");
			
			var data = [for ( x in db.Contract.getActiveContracts(app.user.amap)){label:x.name, value:x.id} ];
			for ( d in data.copy()) if (d.value == c.id ) data.remove(d);
			
			f.addElement(new sugoi.form.elements.IntSelect("contract", "Contrat", data));
			view.form = f;
			if (f.isValid()) throw Redirect("/p/who/link/" + c.id + "/" + f.getValueOf("contract"));
			
		}else{
			
			view.c2 = c2;
			var products = who.db.WProductLink.get(c);
			view.products = products;
			
			if (app.params.exists("autolink") && products.length==0){
				
				who.db.WProductLink.autolink(c, c2);
				throw Ok("/p/who/link/" + c.id + "/" + c2.id, "Association automatique faite");
			}
		}
		*/
	}
	
	
	@logged @tpl("plugin/who/balance.mtt")
	public function doBalance(d:db.Distribution){
		
		init(d.contract);
		
		var conf = who.db.WConfig.getOrCreate(d.contract);
		
		var products = who.db.WProductLink.getLinks(d.contract,conf.contract2,true);
		view.products = products;
		view.d = d;
		view.totalOrder = function(p:db.Product){
			
			var orders = db.UserContract.manager.search($distribution == d && $product == p, false);			
			var tot = 0.0;
			for ( o in orders ) tot += o.quantity;
			return tot;
			
		}
		
		checkToken();
		
	}
	

	
	@logged @tpl("plugin/who/balance.mtt")
	public function doConfirm(d:db.Distribution){
		
		if (checkToken()){
			init(d.contract);
			var d2 = who.db.WProductLink.confirm(d);
			
			//if cpro contract
			var msgPro = "";
			if ( connector.db.RemoteCatalog.getFromContract(d2.contract) != null ){
				msgPro = "<br/>Elle a été transmise automatiquement à <b>"+d2.contract.vendor.name+"</b>.<br/>Il ne reste plus qu'a patienter jusqu'à la distribution...";
			}			
			
			throw Ok("/contractAdmin/orders/"+d2.contract.id+"?d="+d2.id,"Votre commande a bien été tranformée en commande de gros ! "+msgPro);	
		}
	}
	
	
	@logged @tpl("plugin/who/detail.mtt")
	public function doDetail(d:db.Distribution, p:db.Product){
		
		var conf = who.db.WConfig.getOrCreate(d.contract);		
		var links = who.db.WProductLink.getLinks(d.contract,conf.contract2);
		var retailToWholesale = who.db.WProductLink.linksAsMap(links);
		
		init(d.contract);
		
		view.orders = db.UserContract.prepare( db.UserContract.manager.search($distribution == d && $product == p, false) );
		view.p1 = p;
		view.p2 = retailToWholesale[p.id];
		view.d = d;
		
		//update quantities
		if (checkToken()){
			//{u10748 => 4, u1 => 2, token => b49d318e22952b2454c1f92e05d1078a}
			
			for (k in app.params.keys() ){
				if (k.substr(0, 1) == "u"){
					//trace('user '+k.substr(1)+' prend '+app.params.get(k));
					var userId = Std.parseInt(k.substr(1));
					var qt = Std.parseInt( app.params.get(k) );
					var o  = db.UserContract.manager.select($userId == userId && $product == p && $distribution == d, true);
					db.UserContract.edit(o, qt);					
				}
			}
			
			throw Ok("/p/who/detail/"+d.id+"/"+p.id, "Quantités ajustées");
			
		}
		
	}	
	
	
}