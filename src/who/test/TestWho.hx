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

		//link catalog to a group and enable wholesale order module
		var contract = pro.service.PCatalogService.linkCatalogToGroup(pro.test.ProTestSuite.CATALOG1,test.TestSuite.LOCAVORES,1).getContract();
		var s = new who.service.WholesaleOrderService(contract);
		s.enable();
	}

	function testProductLinks(){
		
		var rcs = connector.db.RemoteCatalog.getFromCatalog(pro.test.ProTestSuite.CATALOG1);
		var contract = rcs.first().getContract();
		
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

	function testConfirmFails(){

		var rcs = connector.db.RemoteCatalog.getFromCatalog(pro.test.ProTestSuite.CATALOG1);
		var contract = rcs.first().getContract();
		var s = new who.service.WholesaleOrderService(contract);
		var placeId = test.TestSuite.LOCAVORES.getPlaces().first().id;

		var d = service.DistributionService.create(
			contract,
			new Date(2029,1,10,0,0,0),
			new Date(2029,1,10,20,0,0),
			placeId,
			null,
			null,
			null,
			null,
			new Date(2029,0,1,0,0,0),
			new Date(2029,0,30,0,0,0),
			null,
			false
		);

		//make orders
		var lemon1 = db.Product.getByRef(contract,"CIT-1");
		var lemon5 = db.Product.getByRef(contract,"CIT-5");
		var lemon10 = db.Product.getByRef(contract,"CIT-10");
		var tomato = db.Product.getByRef(contract,"TOM-1");
		//SEB 2kg lemon
		db.UserContract.make(test.TestSuite.SEB,2,lemon1,d.id);
		//FRA 5kg lemon + 5kg tomato
		db.UserContract.make(test.TestSuite.FRANCOIS,1,lemon5,d.id);
		db.UserContract.make(test.TestSuite.FRANCOIS,5,tomato,d.id);
		//JULIE 10kg Lemon + 1kg tomato
		db.UserContract.make(test.TestSuite.JULIE,1,lemon10,d.id);
		db.UserContract.make(test.TestSuite.JULIE,1,tomato,d.id);

		//we should not be able to confirm the order balancing
		var error = null;
		try{
			s.confirm(d);
		}catch(e:tink.core.Error){
			error = e;
		}
		assertTrue(error!=null);

	}
	

	function testConfirm(){

		var rcs = connector.db.RemoteCatalog.getFromCatalog(pro.test.ProTestSuite.CATALOG1);
		var contract = rcs.first().getContract();
		var s = new who.service.WholesaleOrderService(contract);
		var placeId = test.TestSuite.LOCAVORES.getPlaces().first().id;

		var d = service.DistributionService.create(
			contract,
			new Date(2029,1,10,0,0,0),
			new Date(2029,1,10,20,0,0),
			placeId,
			null,
			null,
			null,
			null,
			new Date(2029,0,1,0,0,0),
			new Date(2029,0,30,0,0,0),
			null,
			false
		);

		//make orders
		var lemon1 = db.Product.getByRef(contract,"CIT-1");
		var lemon5 = db.Product.getByRef(contract,"CIT-5");
		var lemon10 = db.Product.getByRef(contract,"CIT-10");
		var tomato = db.Product.getByRef(contract,"TOM-1");

		//SEB 2kg lemon
		db.UserContract.make(test.TestSuite.SEB,2,lemon1,d.id);
		//FRA 5kg lemon + 5kg tomato
		db.UserContract.make(test.TestSuite.FRANCOIS,1,lemon5,d.id);
		db.UserContract.make(test.TestSuite.FRANCOIS,5,tomato,d.id);
		//JULIE 10kg Lemon + 1kg tomato
		db.UserContract.make(test.TestSuite.JULIE,1,lemon10,d.id);
		db.UserContract.make(test.TestSuite.JULIE,1,tomato,d.id);

		//do balancing
		var uo = db.UserContract.make(test.TestSuite.SEB,3,lemon1,d.id);
		assertEquals(5.0,uo.quantity); //seb should have now 5 x lemon 1kg
		s.confirm(d);

		/*we should get :
		2 x 10kg lemon
		6 x 1kg tomato
		*/
		var summary = db.UserContract.getOrdersByProduct({distribution:d});
		assertEquals(summary.length,2);
		var slemon = Lambda.find(summary,function(x) return x.pid == lemon10.id);
		assertEquals(2.0,slemon.quantity);
		var stomato = Lambda.find(summary,function(x) return x.pid == tomato.id);
		assertEquals(6.0,stomato.quantity);


	}
}