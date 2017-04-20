package who.db;
import sys.db.Object;
import sys.db.Types;
import Common;


class WConfig extends Object
{
	public var id : SId;
	
	@:relation(contractId)
	public var contract : db.Contract;			
	
	public var active : SBool;
	public var delay : SInt; //number of days after orders closing to complete the wholesale order
	
	
	public static function isActive(c:db.Contract):WConfig{
		
		var x = manager.select($contract == c, false);
		if (x != null && x.active){
			return x;
		}else{
			return null;
		}
		
	}
	
	public static function getOrCreate(c:db.Contract):WConfig{
		
		var x =  manager.select($contract == c, true);
		if (x == null){
			x = new WConfig();
			x.contract = c;
			x.active = false;
			x.delay = 3;
			x.insert();
		}
		return x;
		
	}
	
	
}

