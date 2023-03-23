pragma solidity >0.8.0 <= 0.8.17;

import "./libs/IdGeneratorLib.sol";
import "./AccountModule.sol";

contract ProductModule{
    // event
    event CreateProduct(bytes32 productId, bytes32 hash); 
    event ProductApproved(bytes32 productId);
    event ProductDenied(bytes32 productId);
    //enum && structs
    enum ProductStatus {
        Approving,
        Approved,
        Denied
    }
    
    struct ProductInfo{
        bytes32 hash;
        bytes32 owner;
        ProductStatus status;
    }
    
    struct VoteInfo {
        uint256 agreeCount;
        uint256 denyCount;
        mapping(bytes32=>bool) voters;
        uint256 threshold;
    }
    //status

    AccountModule private accountContract;
    mapping(bytes32 => ProductInfo) products;
    mapping(bytes32 => bytes32) private hashToId;
    mapping(bytes32 => uint256) private ownerProductCount;
    mapping(bytes32 => VoteInfo) private productCreationVotes;
    
    //constructor
    constructor(address _accountContract) {
        accountContract = AccountModule(_accountContract);
    }

    //functions
    function createProduct(bytes32 hash) external returns(bytes32 productId){
        require(hash != bytes32(0), "Invalid hash");
        AccountModule.AccountData owner = accountContract.getAccountByAddress(addr);
        require(owner.accountStatus == AccountType.Approved, "Address not approved");
        require(owner.accountType == AccountType.Company, "Account is not company");
        require(hashToId[hash] == 0, "duplicate product hash");
        
        uint256 ownerNonce = ownerProductCount[owner.did];
        productId = IdGeneratorLib.generateId(owner.did, ownerNonce);
        products[productId] = ProductInfo(hash, owner.did, ProductStatus.Approving);
        hashToId[hash] = productId;
        ownerNonce++;
        ownerProductCount[owner.did] = ownerNonce;
        
        productCreationVotes[productId] = VoteInfo({
            threshold: accountContract.accountTypeNumbers(AccountType.Witness)
        });
        emit CreateProduct(productId, hash);
    }


    function approveProduct(bytes32 productId, bool agree) external{
        AccountModule.AccountData owner = accountContract.getAccountByAddress(addr);
        require(owner.accountStatus == AccountType.Approved, "Address not approved");
        require(owner.accountType == AccountType.Witness, "Account is not witness");
        ProductInfo storage product = products[productId];
        require(product.status == ProductStatus.Approving, "Invalid product status");
        VoteInfo storage voteInfo = productCreationVotes[productId];
        require(!voteInfo.voters[owner.did], "Duplicate vote");
        uint256 threshold = voteInfo.threshold;
        if (agree){
            uint256 agreeCount = voteInfo.agreeCount + 1;
            voteInfo.agreeCount = agreeCount;
            if (agreeCount >= threshold){
                product.status = ProductStatus.Approved;
                emit ProductApproved(productId);
            }

        } else{
            uint256 denyCount = voteInfo.denyCount + 1;
            voteInfo.denyCount = denyCount;
            if (denyCount >= threshold){
                product.status = ProductStatus.Denied;
                emit ProductDenied(productId);
            }
        }
        voteInfo.voters[owner.did] = true;
    }

}