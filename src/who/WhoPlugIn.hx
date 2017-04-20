package who;
import Common;

/**
 * Wholesale Order Plugin
 */
class WhoPlugIn extends plugin.PlugIn implements plugin.IPlugIn{
	
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
					nav.push({name:"Commande en gros", link:"/p/who/"+cid,icon:"th"});		
				}
				
			case HourlyCron:
				
		
		
			default :
		}
	}
	

	
	public function getName() {
		return name;
	}
	
	public function getController() {
		return null;
	}
	
	public function isInstalled():Bool {
		
		var a = sys.FileSystem.exists(App.config.PATH + "/www/plugin/" + name);
		var b = sys.FileSystem.exists(App.config.PATH + "/lang/fr/tpl/plugin/" + name);
		
		return a && b;
	}
	
	public function install() {
		
	
	}
	
}