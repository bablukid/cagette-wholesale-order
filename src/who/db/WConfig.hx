package who.db;
import sys.db.Object;
import sys.db.Types;
import Common;


class WConfig extends Object
{
	public var id : SId;
	
	@formPopulate("populate") @:relation(contract1Id) public var contract1 : db.Contract;			
	@formPopulate("populate") @:relation(contract2Id) public var contract2 : SNull<db.Contract>;			
	
	public var active : SBool;
	//public var delay : SInt; //number of days after orders closing to complete the wholesale order
	
	
	public static function isActive(c:db.Contract):WConfig{
	
		var x = manager.select($contract1 == c, false);
		if (x != null && x.active){
			return x;
		}else{
			return null;
		}	
	}
	
	public static function getOrCreate(c:db.Contract):WConfig{
		
		var x =  manager.select($contract1 == c, true);
		if (x == null){
			x = new WConfig();
			x.contract1 = c;
			x.active = false;
			//x.delay = 3;
			x.insert();
		}
		return x;
	}
	
	/**
	 * get active contracts
	 * @return
	 */
	public function populate():sugoi.form.ListData.FormData<Int>{
		
		var out = [];
		for (v in App.current.user.amap.getActiveContracts()) {
			if(v.id!=this.contract1.id)
				out.push({label:v.name, value:v.id });
		}
		return out;
	}
	
	
}

