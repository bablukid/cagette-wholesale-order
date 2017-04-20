package who.controller;


/**
 * CAGETTE PRO MAIN CONTROLLER
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
	}

	@logged @tpl("plugin/who/default.mtt")
	public function doDefault(c:db.Contract){
		
		view.active = who.db.WConfig.isActive(c);
		
		init(c);
	}
	

	@logged @tpl("plugin/who/config.mtt")
	public function doConfig(c:db.Contract){
		
		init(c);
		
		var conf = who.db.WConfig.getOrCreate(c);
		
		var f = sugoi.form.Form.fromSpod(conf);
		f.removeElementByName("contractId");
		f.getElement("delay").label = "Délai en jours";
		
		if (f.isValid()){
			f.toSpod(conf);
			conf.update();
			throw Ok("/p/who/"+c.id,"Configuration mise à jour");
		}
		
		view.form = f;
	}
	
	@logged @tpl("plugin/who/link.mtt")
	public function doLink(c:db.Contract,?c2:db.Contract){
		
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
		
	}
	
	
}