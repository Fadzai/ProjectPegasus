pragma solidity ^0.4.17;

contract InvestmentFactory{
    address[] public deployedInvestments;
    
    function createInvestment() public {
        //create instance of Investment
        //creates new contract address
        address newInvestment = new Investment(msg.sender);
        //store in deployedInvestments
        deployedInvestments.push(newInvestment);
    }
    
    function getDeployedInvestments() public view returns(address[]){
        return deployedInvestments;
    }
}

contract Investment {
    
    string public urlToDescription;
    string public motivation;
    mapping(address => uint) public investments;
    //totalCost refers to the total cost of investment
    uint public totalCost;
    uint public investorsCount;
    uint public investmentDeadlineTimestamp;
    //the minimum investment applies to the investment initiator
    //it is set to 25% in this case
    uint public minimumInvestment;
    //initial investment is what the initial investor contributes as the seed
    uint public initialInvestment;
    uint public investmentsCount;
    //totalInvestmentMade tracks the total amount of money contributed by investors
    uint public totalInvestmentMade;
    bool public complete;
    //recipient is the initiator of the investment in this case
    address public recipient; 
    //the manager in this case is the investment initiator
    address public manager;
    

    //event to be fired if initial investment is too low
    event InitialInvestmentTooLow(uint expectedMinInvestment);

    //event to be fired when rental payments are made for example
    event PaymentMade(bool rentPaid);

    //states of initial investment
    enum State {NO_INITIAL_INVESTMENT, BELOW_THRESHOLD, ABOVE_THRESHOLD}

    //states of investment
    enum InvestmentState {INVESTMENT_REQUEST_OPENED, FAILED_DEADLINE_EXPIRED, INVESTMENT_RAISED, INVESTMENT_WITHDRAWN}

    //initialInvestmentState defaults to NO_INITIAL_INVESTMENT
    State public initialState = State.NO_INITIAL_INVESTMENT;

    //investmentState defaults to INVESTMENT_REQUEST_OPENED
    State public investmentState = InvestmentState.INVESTMENT_REQUEST_OPENED;

    modifier restricted(){
        require(msg.sender == manager);
        _;
    }

    //modifier to track state of initial investment
    modifier inState(State expectedState){
        require(initialState == expectedState);
        _;
    }

    //modifier to track state of investment
    modifier inInvestmentState(State expectedState){
        require(investmentState == expectedState);
        _;
    }

   //@Investment is the constructor, when called it sets the minimum investment and sets the manager to the creator of the contract
   //the creator of the contract is the initial investor
    function Investment(address creator) public {
        manager = creator;
        minimumInvestment = 25/100 * totalCost;
        if(msg.value > minimumInvestment){
            initialInvestment = msg.value;
            initialState = State.ABOVE_THRESHOLD;
            totalInvestmentMade += msg.value;
            investorsCount++;
        }
        else{
            initialState = State.BELOW_THRESHOLD;
            emit InitialInvestmentTooLow(minimumInvestment);
        }
    }
    
    //@makeInitialInvestment allows the initial investment to be set outside of the constructor
    function makeInitialInvestment(uint initial) public payable restricted inState(State.BELOW_THRESHOLD)  {
        if(msg.value > minimumInvestment){
            initialInvestment = msg.value;
            initialState = State.ABOVE_THRESHOLD;
            totalInvestmentMade += msg.value;
            investorsCount++;
        }
        else{
            emit InitialInvestmentTooLow(minimumInvestment);
        }
    }

    //@invest called by investors that wish to contribute towards the property
    function invest() public payable{
        //minimum investment not imposed on investors in order to keep investment open to all
        //require(msg.value > minimumInvestment);
        investments[msg.sender] += msg.value;
        investorsCount++;
        totalInvestmentMade += msg.value;
        if(totalInvestmentMade == totalCost){
            investmentState = InvestmentState.INVESTMENT_RAISED;
        }

    }
 
    //@getSummary called when form with details of the investment is displayed
    function getSummary() public view returns (string, string, uint, uint, uint) {
        return (
            urlToDescription,
            motivation,
            totalCost,
            investmentDeadlineTimestamp,
            totalInvestmentMade
        );
    }

    //if the investment has been raised and withdrawn (to pay for the property) then payments like rentals can start being made
    //@sendPayments called by tenants
    function sendPayments() public payable inInvestmentState(InvestmentState.INVESTMENT_WITHDRAWN) {
        emit PaymentMade(true);
    }

    //@withdrawInvestment called by the initial investor
    function withdrawInvestment() public restricted inInvestmentState(InvestmentState.INVESTMENT_RAISED) returns (bool) {
        uint amount = totalInvestmentMade;
        if(amount > 0) {
            //update totalInvestmentMade to indicate that the initial investor has made their withdrawal
            //this is easily reversed if the withdrawal is unsuccessful
            //better failsafe than updating after withdrawal (where in the worst case contract ether could be drained)
            investmentState = InvestmentState.INVESTMENT_WITHDRAWN;       
            //using send() returns a boolean which can be checked to see if the transfer was successful
            if (!msg.sender.send(amount)) {
                //if not successful, then set back original amount
                investmentState = InvestmentState.INVESTMENT_RAISED;       
                return false;
            }
        }
        investmentState = InvestmentState.INVESTMENT_WITHDRAWN;       
        return true;
    }

    //@withdraw called by the individual investors to either get refunds or withdraw their rentals
    function withdraw() public returns (bool) {
        if(investmentState == FAILED_DEADLINE_EXPIRED) || (investmentState == INVESTMENT_WITHDRAWN)
        uint amount = investments[msg.sender]/totalInvestmentMade * this.balance;
        if(amount > 0) { 
            //using send() returns a boolean, check to see if transfer is successful
            //send transfers and checks
            if (!msg.sender.send(amount)) {
                //if not successful, then set back original amount
                investments[msg.sender] = amount;
                return false;
            }
        }
        return true;
    }
}