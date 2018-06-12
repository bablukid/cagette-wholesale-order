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
	
	/**
	 *  check rights and prepare nav
	 */
	function init(c){
		
		if (!app.user.isContractManager(c)) throw Error("/", t._("Access forbidden") );
		
		new controller.ContractAdmin().sendNav(c);
		view.c = c;
		view.nav = ["contractadmin","who"];
	}

	@logged @tpl("plugin/who/default.mtt")
	public function doDefault(c:db.Contract){
		init(c);
		var s = new who.service.WholesaleOrderService(c);
		
		if(checkToken() && app.params.exists("toggle")){
			if( connector.db.RemoteCatalog.getFromContract(c) ==null){
				throw Error("/p/who/"+c.id,"Les commandes en gros ne sont possibles qu'avec les contrats Cagette Pro pour l'instant");
			} 
			s.conf.lock();
			s.conf.active = !s.conf.active;
			s.conf.update();
		}
		
		view.active = s.conf.active;
		view.distributions = s.getDistributions();
		view.links = s.getLinks(true);
	}
	
	/*
	@logged @tpl("plugin/who/config.mtt")
	public function doConfig(c:db.Contract){
		
		init(c);
		
		var conf = who.db.WConfig.getOrCreate(c);
		
		var f = sugoi.form.Form.fromSpod(conf);
		f.removeElementByName("contract1Id");
		var e = f.getElement("contract2Id");
		e.label = "Contrat en gros correspondant";
		
		if (f.isValid()){
			f.toSpod(conf);
			
			conf.update();
			
			if (conf.active && conf.contract2 == null){
				throw Error("/p/who/config/"+c.id , "Il faut choisir un contrat de gros correspondant à votre contrat au détail");
			}
			
			if(conf.active){
				//if no links are found, error
				var links = who.db.WProductLink.getLinks(conf.contract1, conf.contract2, true);
				if(links==null) throw Error("/p/who/"+c.id , "Configuration invalide.");
				if (links.length == 0) throw Error("/p/who/"+c.id , "Le contrat choisi est incompatible avec <b>"+c.name+"</b>");
			}
			
			//same group ?
			if ( conf.contract1.amap.id != conf.contract2.amap.id){
				throw Error("/p/who/"+c.id , "Les deux contrats ne font pas partie du même groupe.");
			}
			
			throw Ok("/p/who/"+c.id,"Configuration mise à jour");
		}
		
		view.form = f;
	}*/
	
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
		
		var s = new who.service.WholesaleOrderService(d.contract); 
		
		var products = s.getLinks(true);
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
			var s = new who.service.WholesaleOrderService(d.contract); 
			var d2 = s.confirm(d);
			
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
		
		var s = new who.service.WholesaleOrderService(d.contract); 
		var links = s.getLinks();
		var retailToWholesale = who.service.WholesaleOrderService.linksAsMap(links);
		
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