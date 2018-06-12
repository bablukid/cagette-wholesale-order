package who.test;
import Common;
import pro.service.PProductService;

/**
 * Test wholesale orders plugin
  * @author fbarbut
 */
class TestWho extends haxe.unit.TestCase
{
	

	public function new(){
		super();
	}
	
	override function setup(){

		//restore initial state
		test.TestSuite.initDB();
		test.TestSuite.initDatas();
		//add Cpro datas
		pro.test.ProTestSuite.initDB();
		pro.test.ProTestSuite.initDatas();

		test.TestSuite.createTable(who.db.WConfig.manager);

		//product Lemon in 3 qt : 1kg, 5kg, 10kg
		var lemon = PProductService.make("Citron",Kilogram,"CIT",pro.test.ProTestSuite.COMPANY);
		for( qt in [1,5,10] ){
			var off = PProductService.makeOffer(lemon,qt,"CIT-"+qt);
			PProductService.makeCatalogOffer(off,pro.test.ProTestSuite.CATALOG1,1);			
		}

		//simple product with no link
		var tomato = PProductService.make("Tomato",Kilogram,"TOM",pro.test.ProTestSuite.COMPANY);
		var off = PProductService.makeOffer(tomato,1,"TOM-1");
		PProductService.makeCatalogOffer(off,pro.test.ProTestSuite.CATALOG1,3);			

		//link catalog to a group
		var contract = connector.db.RemoteCatalog.createContractFromRemoteCatalog(pro.test.ProTestSuite.CATALOG1,test.TestSuite.LOCAVORES,1);
		var s = new who.service.WholesaleOrderService(contract);
		s.enable();
	}

	function testProductLinks(){
		
		var rcs = connector.db.RemoteCatalog.getFromCatalog(pro.test.ProTestSuite.CATALOG1);
		var contract = rcs.first().getRelatedContract();
		
		//we got a contract with 4 products
		assertTrue( contract!=null );
		assertTrue( contract.getProducts().length == 4 );
		
		var s = new who.service.WholesaleOrderService(contract);
		var links = s.getLinks();

		//links should list only lemons
		assertTrue( links!=null );
		assertTrue( links.length == 2 );

		//Lemon 1kg -> Lemon 10kg
		assertTrue( links[0].p1.qt == 1 );
		assertTrue( links[0].p2.qt == 10 );
		
		//Lemon 5kg -> Lemon 10kg
		assertTrue( links[1].p1.qt == 5 );
		assertTrue( links[1].p2.qt == 10 );
	}

	function testConfirm(){

		var rcs = connector.db.RemoteCatalog.getFromCatalog(pro.test.ProTestSuite.CATALOG1);
		var contract = rcs.first().getRelatedContract();
		var s = new who.service.WholesaleOrderService(contract);

		var d = new Distribution();
		d.contract = contract;
		d.date = new Date(2030,1,1);
		d.orderStartDate = new Date(2010,1,1);
		d.orderEndDate = new Date(2030,0,1);
		d.insert();

		//make orders
		var lemon1 = db.Product.getByRef(contract,"CIT-1");
		var lemon1 = db.Product.getByRef(contract,"CIT-5");
		var lemon1 = db.Product.getByRef(contract,"CIT-10");
		var tomato = db.Product.getByRef(contract,"TOM-1");

		db.UserContract.make(test.TestSuite.SEB,2,lemon1,d.id);
		db.UserContract.make(test.TestSuite.FRANCOIS,1,lemon1,d.id);



	}
}