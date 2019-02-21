package who;
import Common;
import datetime.DateTime;
import sugoi.plugin.*;

/**
 * Wholesale Order Plugin
 */
class WhoPlugIn extends PlugIn implements IPlugIn{
	
	public function new() {
		super();
		name = "wholesale-order";
		file = sugoi.tools.Macros.getFilePath();
		//suscribe to events
		App.current.eventDispatcher.add(onEvent);
	}
	
	public function onEvent(e:Event) {
		
		switch(e) {
			case Nav(nav, name, cid):
				
				if(name=="contractAdmin"){
					nav.push({id:"who",name:"Commande en gros", link:"/p/who/"+cid,icon:"wholesale"});		
				}
				
			case HourlyCron :
				
				//send email to ask to equilibrate order 
				var from = DateTime.now().add(Hour(-1)).snap(Hour(Down)).format('%F %T');
				var to = DateTime.now().add(Hour( -1)).snap(Hour(Up)).format('%F %T');
				
				//select distribs which closed last hour with an active WConfig linked
				var sql = 'select d.* from Distribution d,WConfig c where orderEndDate >= "$from" and orderEndDate < "$to" and contractId=contract1Id and c.active=1';
				var distribs = db.Distribution.manager.unsafeObjects(sql,false);
				
				//throw 'WHO : $from $to';
				
				for ( d in distribs){
					var user = d.contract.contact;
					var m = new sugoi.mail.Mail();
					m.addRecipient(user.email , user.firstName+" " + user.lastName);
					m.setSender(App.config.get("default_email"),"Cagette.net");
					m.setSubject("Commande à ajuster : "+d.contract.name);
					
					var orders = d.getOrders();
					
					var html = App.current.processTemplate("plugin/who/mail/asktobalance.mtt", { group:d.contract.amap,d:d,orders:orders } );
					m.setHtmlBody(html);
					App.sendMail(m,d.contract.amap);
					
					Sys.sleep(0.25);
				}
				
			/*case Blocks(blocks, name):
				if (name == "home" ){
					
					//find distributions with wholesale-order plugin activated
					if (App.current.user == null || App.current.user.amap == null) return;
					var now = Date.now();
					var cids = db.Contract.getActiveContracts(App.current.user.amap);
					//distributions who are in between startDate and delivery date
					var dists = db.Distribution.manager.search($orderStartDate <= now && $date >= now && $contractId in (tools.ObjectListTool.getIds(cids)), {orderBy:date}, false);
					for (d in dists){
						
						var conf = who.db.WConfig.isActive(d.contract);
						if ( conf != null){
						
							var html = App.current.processTemplate("plugin/who/block/home.mtt", {d:d});
							blocks.push( {id:"who",title:"Commandes en gros",html:html});
						}
						
					}
				}		*/			
			

			case MultiDistribEvent(md):
				// display a button on the homepage
				if (App.current.user == null || App.current.user.amap == null) return;
				for (d in md.distributions){						
					var conf = who.db.WConfig.isActive(d.contract);
					if ( conf != null){
						//md.actions.push({id:"who",link:"javascript:_.overlay('/p/who/popup/"+d.id+"','Commande en gros')",name:"Commande en gros",icon:"th"});

						var s = new who.service.WholesaleOrderService(d.contract);

						var params : Dynamic = {};
						params.balancing = s.getBalancingSummary(d);
						params.d = d;
						params.manager = App.current.user.isContractManager(d.contract);
						params.unit = App.current.view.unit;
						params.now = Date.now();						

						var html = App.current.processTemplate("plugin/who/block/home.mtt", params);
						md.extraHtml += html;
					}
				}

			case ProductInfosEvent(productInfos,distribution) :

				//display a block in product infos popup
				if(distribution==null) return null;
				var c = db.Contract.manager.get(productInfos.contractId,false);
				var conf = who.db.WConfig.isActive(c);
				if ( conf != null){
					if(productInfos.desc==null) productInfos.desc = "";

					var s = new who.service.WholesaleOrderService(c);
					var p = db.Product.manager.get(productInfos.id,false);
					var balancing = s.getBalancingSummary(distribution,p);
					if(balancing==null) return null;

					var html = App.current.processTemplate("plugin/who/block/productInfos.mtt",{
						balancing:balancing,
						d:distribution,
						unit:App.current.view.unit,
						Math:Math
					});

					productInfos.desc += "<br/><hr/>"+html;
				}
			
		
			default :
		}
	}
	
}