pragma solidity ^0.4.17;

contract CampaignFactory{
    address[] public deployedCampaigns;
    
    function createCampaign(uint minimum) public {
        //create instance of Campaign
        address newCampaign = new Campaign(minimum, msg.sender);
        //store in deployedCampaigns
        deployedCampaigns.push(newCampaign);
    }
    
    function getDeployedCampaigns() public view returns(address[]){
        return deployedCampaigns;
    }
}

contract Campaign {
    
    struct Request {
        string description;
        uint value;
        address recipient;
        bool complete;
        uint approvalCount;
        mapping(address => bool) approvals;
    }
    
    Request[] public requests;
    address public manager;
    uint public minimumContribution;
    mapping(address => bool) public approvers;
    uint public approversCount;
    uint public totalContribution;
    
    modifier restricted(){
        require(msg.sender == manager);
        _;
    }
    
    function Campaign(uint minimum, address creator) public {
        manager = creator;
        minimumContribution = minimum;
    }
    
    function contribute() public payable{
        require(msg.value > minimumContribution);
        approvers[msg.sender] = true;
        approversCount++;
        totalContribution += msg.value;
    }
    
    function createRequest(string description, uint value, address recipient) 
        public restricted 
    {
        Request memory newRequest = Request({
           description: description,
           value: value,
           recipient: recipient,
           complete: false,
           approvalCount: 0
        });
        
        requests.push(newRequest);
    }
    
    function approveRequest(uint index) public {
        //manipulate copy in storage
        Request storage request = requests[index];
        
        //ensure person is a contributor to campaign
        require(approvers[msg.sender]);
        //check that contributor has not voted on request yet
        require(!request.approvals[msg.sender]);
        
        //register the contributor's vote
        request.approvals[msg.sender] = true;
        //increment total approval counts
        request.approvalCount++;
    }
    
    function finalizeRequest(uint index) public restricted {
        //manipulate copy in storage
        Request storage request = requests[index];
        
        //check that request has not been finalized yet
        require(!request.complete);
        
        //check that more than 50% of contributors voted yes for request
        require(request.approvalCount > (approversCount/2));
        
        //send money to recipient
        request.recipient.transfer(request.value);
        
        //update request as finalized
        request.complete = true;
    }

    function getSummary() public view returns (
        uint, uint, uint, uint, address
    ) {
        return (
            minimumContribution,
            this.balance,
            requests.length,
            approversCount,
            manager
        );
    }

    function getRequestsCount() public view returns (uint) {
        return requests.length;
    }
}