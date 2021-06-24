pragma solidity 0.4.24;


contract StockExchange {

    struct Share {
        string companyId;
        uint qty;
    }

    struct AnonAccount {
        Share myShare;
        bool lock;
    }

    struct Request {
        uint requesterNIN;
        uint numberofShares;
        uint remainingShares;
        uint price;
    }

    struct Offer {
        uint offerNIN;
        uint numberofShares;
        uint remainingShares;
        uint price;
    }

    struct Trade {
        uint offerNIN;
        uint requestNIN;
        uint numberofShares;
        uint price;
    }

    address private SE = 0x392A558eB331b54c2f15e4E40B3B3cf3CE123bCA;    // Your SE  @ here
    address private CSD = 0x392A558eB331b54c2f15e4E40B3B3cf3CE123bCA;   // Your CSD @ here

    mapping (address => AnonAccount) accounts;
    Request[] requests;
    Offer[] offers;
    Trade[] trades;
    //uint addessIndexMap=0;


    event LogNinCreated(address _anonNin, uint qty);
    event LogCompanyCreated(address _addr, string _symbol, uint qty, uint _price);
    event SharestoNinAssigned(address _addr, string _symbol, uint _qty, uint _nin);
    event BuyerAdded(uint _buyerNin, uint _sharesQuantity, uint _price);
    event SellerAdded(uint _sellerNin, uint _sharesQuantity, uint _price);
    event NoSufficentShares (uint _totalShares, uint _sharesQuantity);
    event NewTrade(uint offerNIN, uint requesterNIN, uint thisShare, uint pric);
    event PriceCheck(uint offerPrice, uint requestPrice);

    modifier csdOnly() {
        require(msg.sender == CSD);
        _;
    }

    modifier seOnly() {
        require(msg.sender == SE);
        _;
    }

    modifier ninUnlocked(address _nin) {
        require(!accounts[_nin].lock);
        _;
    }

    function addAnonymousNin(address _anonNin, uint _shareQty) public
        csdOnly()
    {
        storeAndLogNewNiN(_anonNin, _shareQty);
    }  
    
    function lockAccounts() public
        csdOnly()
    {
        for (uint i; i<accounts.length; i++) {
            accounts[i].lock = true;
        }
    }

    function buyShares( uint _buyerNin, uint _sharesQuantity, uint price) public
    {
        storeAndLogBuyShares(_buyerNin, _sharesQuantity, price);
        doMatch();
        // a function to match buyer with seller if available
        // remove the buyer from the queue (pop out)
    }

    function sellShares( uint _sellNin, uint _sharesQuantity, uint price, address _addr) public
    {
        //need to check if seller has this share number or not
        if (accounts[_addr].myShare.qty < _sharesQuantity) {
            emit NoSufficentShares(accounts[_addr].myShare.qty, _sharesQuantity);
            return;
        }
        storeAndLogSellShares(_sellNin, _sharesQuantity, price);
        doMatch(); 
        // a function to match buyer with seller if available
        // remove the buyer from the queue (pop out)
    }

    function matchTrades(address _addr) public 
        seOnly()
    {
        doMatch();
    }

    function storeAndLogNewNiN(address _anonNin, uint _shareQty) private {
        accounts[_anonNin].myShare.qty = _shareQty;
        accounts[_anonNin].lock = false;
        emit LogNinCreated(_anonNin, _shareQty);   
    }

    function storeAndLogBuyShares(uint _buyerNin, uint _sharesQuantity, uint _price) private {
        requests.push(Request(_buyerNin, _sharesQuantity, 0, _price));
        sortMaximumFirst();
        emit BuyerAdded(_buyerNin, _sharesQuantity, _price);
    }
    /*
    - This function takes each new element and compares it to the array, place it in its location and sort
    */

    function sortMaximumFirst() private
    {
        Request memory temp;
        for (uint j = 0; j < requests.length-1; j++) {
            if (requests[requests.length-1].price < requests[j].price) {
                temp = requests[j];
                requests[j] = requests[requests.length-1];
                requests[requests.length-1] = temp;
            }
        }
    }

    function storeAndLogSellShares(uint _sellNin, uint _sharesQuantity, uint _price) private 
    {
        offers.push(Offer(_sellNin, _sharesQuantity, 0, _price));
        sortMinFirst();
        emit SellerAdded(_sellNin, _sharesQuantity, _price);
    }

    function sortMinFirst() private
    {
        Offer memory temp;
        for (uint j = 0; j < offers.length; j++) {
            if (offers[offers.length-1].price > offers[j].price) {
                temp = offers[j];
                offers[j] = offers[offers.length-1];
                offers[offers.length-1] = temp;
            }
        }
    }

    function doMatch() private 
    {

        if (offers.length > 0 && requests.length > 0) { //this means we have offer and we have requests
            if (offers[offers.length-1].price <= requests[requests.length-1].price) {
                //emit priceCheck(offers[offers.length-1].price,requests[requests.length-1].price);
                Offer memory thisOffer = offers[offers.length-1];
                Request memory thisRequest = requests[requests.length-1];

                uint thisShare = thisRequest.remainingShares;
                if (thisOffer.remainingShares < thisRequest.remainingShares) {
                    thisShare = thisOffer.remainingShares;
                    thisRequest.remainingShares = thisRequest.remainingShares - thisShare;
                    thisOffer.remainingShares = 0;
                } else 
                    if (thisOffer.remainingShares > thisRequest.remainingShares) {
                        thisShare = thisRequest.remainingShares;
                        thisOffer.remainingShares = thisOffer.remainingShares - thisShare;
                        thisRequest.remainingShares = 0;
                    } else {
                        thisShare = thisRequest.remainingShares;
                        thisOffer.remainingShares = 0;
                        thisRequest.remainingShares = 0;
                    }

                offers[offers.length-1] = thisOffer;
                requests[requests.length-1] = thisRequest;
                if (thisOffer.remainingShares == 0)
                    shiftOffer();
                if (thisRequest.remainingShares == 0)
                    shiftRequest();
                //emit newTrade(thisOffer.offerNIN,thisRequest.requesterNIN,thisRequest.CompanyId,thisShare,thisOffer.price);
                trades.push(Trade(thisOffer.offerNIN, thisRequest.requesterNIN, thisShare, thisOffer.price));
                                //I ADDED THIS TO TEST 
                while ((offers[offers.length-1].price <= requests[requests.length-1].price) && thisRequest.remainingShares != 0) {
                    doMatch();
                }
            }
        }
    }

    function shiftOffer() private 
    {
        /*for (uint i = 0; i < offers.length - 1; i++) {
            offers[i] = offers[i + 1];
        }*/
        delete offers[offers.length - 1];
        offers.length--;
    }

    function shiftRequest() private
    {
        /*if(requests.length == 0)
            return;*/
        /*for (uint i = 0; i < requests.length - 1; i++) {
            requests[i] = requests[i + 1];
        }*/
        delete requests[requests.length - 1];
        requests.length--;
    }


    function execute() public // This is an example
    {
        addAnonymousNin(0x29455b405822655ccc5b6aa4037cd8d83d7d9208,123);
        addAnonymousNin(0xe504ff08dbce241769745280898d33311fcc31f3,456);
        addAnonymousNin(0xa5c70abfc34d35b571038d3e75906285fc9573b9,789);

        buyShares(123,100,10);
        buyShares(456,200,50);
        buyShares(789,300,100);

        sellShares(789,300,200,0xa5c70abfc34d35b571038d3e75906285fc9573b9);
        sellShares(123,100,80,0x29455b405822655ccc5b6aa4037cd8d83d7d9208);
        sellShares(456,200,50,0xe504ff08dbce241769745280898d33311fcc31f3);
        sellShares(456,150,40,0xe504ff08dbce241769745280898d33311fcc31f3);
        sellShares(123,60,40,0x29455b405822655ccc5b6aa4037cd8d83d7d9208);

    }



}

