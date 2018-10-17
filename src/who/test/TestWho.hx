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

	/**
		run before each test
	**/
	override function setup(){

		//restore initial state
		test.TestSuite.initDB();
		test.TestSuite.initDatas();

		//add Cpro datas
		pro.test.ProTestSuite.initDB();
		pro.test.ProTestSuite.initDatas();

		test.TestSuite.createTable(who.db.WConfig.manager);

		//product Lemon with 3 offers : 1kg, 5kg, 10kg
		var lemon = PProductService.make("Lemon",Kilogram,"CIT",pro.test.ProTestSuite.COMPANY);
		lemon.wholesale = true;
		lemon.update();
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

		//check products ref
		var lemon1 = db.Product.getByRef(contract,"CIT-1");
		var lemon5 = db.Product.getByRef(contract,"CIT-5");
		var lemon10 = db.Product.getByRef(contract,"CIT-10");
		var tomato = db.Product.getByRef(contract,"TOM-1");
		assertEquals(lemon1.contract.id,contract.id);
		assertEquals(lemon5.contract.id,contract.id);
		assertEquals(lemon10.contract.id,contract.id);
		assertEquals(tomato.contract.id,contract.id);
		assertEquals(lemon1.getName(),"Lemon 1 Kg.");
		assertEquals(lemon10.getName(),"Lemon 10 Kg.");
		
		//check cache is empty
		assertTrue( sugoi.db.Cache.manager.count(true)==0 );

		var s = new who.service.WholesaleOrderService(contract);

		var offs = s.sortOffersByQt(Lambda.array(pro.db.PProduct.getByRef("CIT",pro.test.ProTestSuite.CATALOG1.company).getOffers(false)));
		assertEquals(offs[0].quantity,10); //first should be Lemon 10kg.
		assertEquals(offs[1].quantity,5);
		assertEquals(offs[2].quantity,1);

		var links = s.getLinks();

		// trace(links);

		//links should list only lemons
		assertTrue( links!=null );
		assertTrue( links.length == 2 );

		//Lemon 5kg -> Lemon 10kg
		assertTrue( links[0].p1.qt == 5 ); //
		assertTrue( links[0].p2.qt == 10 );
		
		//Lemon 1kg -> Lemon 10kg
		assertTrue( links[1].p1.qt == 1 );
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
		service.OrderService.make(test.TestSuite.SEB,2,lemon1,d.id);
		//FRA 5kg lemon + 5kg tomato
		service.OrderService.make(test.TestSuite.FRANCOIS,1,lemon5,d.id);
		service.OrderService.make(test.TestSuite.FRANCOIS,5,tomato,d.id);
		//JULIE 10kg Lemon + 1kg tomato
		service.OrderService.make(test.TestSuite.JULIE,1,lemon10,d.id);
		service.OrderService.make(test.TestSuite.JULIE,1,tomato,d.id);
		//TOTAL 17kg Lemon + 6kg Tomato

		//we should not be able to confirm the order balancing
		// because 17 is not a multiple of 10.
		var error = null;
		try{
			s.confirm(d);
		}catch(e:tink.core.Error){
			error = e;
		}
		// if(error!=null) trace(error);

		assertTrue(error!=null);

	}
	
	/**
	Test orders balancing
	**/
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

		//SEB 2+10kg lemon
		service.OrderService.make(test.TestSuite.SEB,2,lemon1,d.id);
		service.OrderService.make(test.TestSuite.SEB,1,lemon10,d.id);
		//FRA 5kg lemon + 5kg tomato
		service.OrderService.make(test.TestSuite.FRANCOIS,1,lemon5,d.id);
		service.OrderService.make(test.TestSuite.FRANCOIS,5,tomato,d.id);
		//JULIE 10kg Lemon + 1kg tomato
		service.OrderService.make(test.TestSuite.JULIE,1,lemon10,d.id);
		service.OrderService.make(test.TestSuite.JULIE,1,tomato,d.id);

		//SEB +3kg lemon
		var uo = service.OrderService.make(test.TestSuite.SEB,3,lemon1,d.id);
		assertEquals(5.0,uo.quantity); //seb should have now 5 x lemon 1kg
		
		//do balancing
		s.confirm(d);

		/*get total by products, we should get :
		3 x 10kg lemon
		6 x 1kg tomato
		*/
		var summary = service.OrderService.getOrdersByProduct({distribution:d});
		assertEquals(summary.length,2);
		var slemon = Lambda.find(summary,function(x) return x.pid == lemon10.id);
		assertEquals(3.0,slemon.quantity);
		var stomato = Lambda.find(summary,function(x) return x.pid == tomato.id);
		assertEquals(6.0,stomato.quantity);

		//check bug of non-aggregation of order lines for the same user after balancing		
		var uo = test.TestSuite.SEB.getOrdersFromDistrib(d);
		assertEquals(1,uo.length);
	}


	function testBalancingSummary(){

		var rcs = connector.db.RemoteCatalog.getFromCatalog(pro.test.ProTestSuite.CATALOG1);
		var contract = rcs.first().getContract();
		var s = new who.service.WholesaleOrderService(contract);
		var placeId = test.TestSuite.LOCAVORES.getPlaces().first().id;

		//add a product to catalog : "Bicarbonate 0.1kg" and "Bicarbonate 1.3kg"
		var p = 	PProductService.make("Bicarbonate",Unit.Kilogram,"BIC",pro.test.ProTestSuite.CATALOG1.company);
		var off1 = 	PProductService.makeOffer(p,0.1,"BIC-1");
		var off2 = 	PProductService.makeOffer(p,1.3,"BIC-2");
		PProductService.makeCatalogOffer(off1,pro.test.ProTestSuite.CATALOG1,2.0);
		PProductService.makeCatalogOffer(off2,pro.test.ProTestSuite.CATALOG1,2.0);
		pro.service.PCatalogService.sync(true,pro.test.ProTestSuite.CATALOG1.id);
		
		//we should have now 6 products in this contract
		assertEquals(6,contract.getProducts().length);

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
		var bicarb = db.Product.getByRef(contract,"BIC-1");

		//SEB 2kg + 10kg lemon
		service.OrderService.make(test.TestSuite.SEB,2,lemon1,d.id);
		service.OrderService.make(test.TestSuite.SEB,1,lemon10,d.id);

		//FRA 5kg lemon + 5kg tomato + 50 bicarb (5kg)
		service.OrderService.make(test.TestSuite.FRANCOIS,1,lemon5,d.id);
		service.OrderService.make(test.TestSuite.FRANCOIS,5,tomato,d.id);
		service.OrderService.make(test.TestSuite.FRANCOIS,50,bicarb,d.id);

		//JULIE 10kg Lemon + 1kg tomato + 41 bicarb (4.1kg)
		service.OrderService.make(test.TestSuite.JULIE,1,lemon10,d.id);
		service.OrderService.make(test.TestSuite.JULIE,1,tomato,d.id);
		service.OrderService.make(test.TestSuite.JULIE,41,bicarb,d.id);

		var balancing = s.getBalancingSummary(d);
		
		//check bicarb summary
		assertEquals( balancing[0].totalQt , 9.1 );
		assertEquals( balancing[0].relatedWholesaleOrder , 7 );
		assertEquals( balancing[0].missing , 0.0 );

		//check lemon 5kg summary = missing 5kg to make 10 kg
		assertEquals( balancing[1].totalQt , 5.0 );
		assertEquals( balancing[1].relatedWholesaleOrder , 0 );
		assertEquals( balancing[1].missing , 5.0 );

		//check lemon 1kg summary = 
		assertEquals( balancing[2].totalQt , 2.0 );
		assertEquals( balancing[2].relatedWholesaleOrder , 0 );
		assertEquals( balancing[2].missing , 8.0 );
	}
}