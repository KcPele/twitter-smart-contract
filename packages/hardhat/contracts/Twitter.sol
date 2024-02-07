//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;


contract Twitter {
    struct Tweet {
        uint256 id;
        address author;
        string content;
        uint256 createdAt;
    }

    struct Message {
        uint256 id;
        string content;
        address from;
        address to;
        uint256 createdAt;
    }

    struct Comment {
    uint256 id;
    uint256 tweetId; // The ID of the tweet this comment is associated with
    address author;
    string content;
    uint256 createdAt;
}

    mapping(uint256 => Tweet) private tweets;
    mapping(address => uint256[]) private tweetsOf;
    mapping(uint256 => Message[]) private conversations;
    mapping(address => address[]) private following;
    mapping(address => mapping(address => bool)) private operators;
    mapping(uint256 => address[]) private tweetLikes;
    mapping(uint256 => mapping(address => bool)) private hasLiked;
    mapping(uint256 => uint256) private retweets; // Maps a tweet ID to its original tweet ID
    mapping(uint256 => Comment[]) private comments; // Maps tweet ID to an array of comments
    mapping(address => mapping(address => bool)) private blocked;



    //events to be emitted
    event Tweeted(address indexed author, uint256 tweetId);
    event Followed(address indexed follower, address indexed followed);
    event MessageSent(address indexed from, address indexed to, uint256 conversationId, uint256 messageId);
    event Retweeted(address indexed author, uint256 tweetId, uint256 retweetId);
    event Liked(address indexed author, uint256 tweetId, address indexed liker);
    event Commented(address indexed author, uint256 tweetId, uint256 commentId);
    event UserBlocked(address indexed blocker, address indexed blockedUser);
    event Unfollowed(address indexed follower, address indexed followed);
    event TweetEdited(uint256 tweetId);
    event TweetDeleted(uint256 tweetId);
    event OperatorRevoked(address indexed operator, address indexed user);


    uint256 private nextTweetId;
    uint256 private nextMessageId;
    uint256 private nextCommentId;
  

    function tweetFromOperator(string calldata _content, address _author) external {
        require(operators[msg.sender][_author], "You are not authorized to tweet on behalf of this user");
       _createTweet(_content, _author);
    }
    function _createTweet(string calldata _content, address _author) private {
        tweets[nextTweetId] = Tweet({id:nextTweetId, author: _author, content: _content, createdAt: block.timestamp});
        tweetsOf[_author].push(nextTweetId);
        emit Tweeted(_author, nextTweetId);
        nextTweetId++;
    }
     function _sendMessage(string calldata _content, address _from, address _to) private {
        uint256 conversationId = generateConversationId(_from, _to);
        conversations[conversationId].push(Message({
            id: nextMessageId,
            content: _content,
            from: _from,
            to: _to,
            createdAt: block.timestamp
        }));
        emit MessageSent(_from, _to, conversationId, nextMessageId);
        nextMessageId ++;
    }

      function tweet(string calldata _content) external {
        _createTweet(_content, msg.sender);
    }

    function generateConversationId (address _from, address _to) public pure returns(uint256) {
            return uint256(keccak256(abi.encode(_from, _to)));
    }
    function sendMessage(string calldata _content, address _from, address _to) external {
        _sendMessage(_content, _from, _to);

    }

    function sendMessageFromOperator(string calldata _content, address _from, address _to) external {
        require(operators[msg.sender][_from], "You are not authorized to send messages on behalf of this user");
        _sendMessage(_content, _from, _to);
    }
    function likeTweet(uint256 _tweetId) external {
    require(!hasLiked[_tweetId][msg.sender], "You have already liked this tweet");
    tweetLikes[_tweetId].push(msg.sender);
    hasLiked[_tweetId][msg.sender] = true;
    emit Liked(tweets[_tweetId].author, _tweetId, msg.sender);
}
    function follow(address _followed) external {
        //msg.sender is following _followed
        following[msg.sender].push(_followed);
        emit Followed(msg.sender, _followed);
    }

function retweet(uint256 _originalTweetId, string calldata _content) external {
    _createTweet(_content, msg.sender);
    uint256 retweetId = nextTweetId - 1; // Assuming _createTweet increments nextTweetId
    retweets[retweetId] = _originalTweetId;
    emit Retweeted(msg.sender, _originalTweetId, retweetId);
}

function commentOnTweet(uint256 _tweetId, string calldata _content) external {
    require(_tweetId < nextTweetId, "Tweet does not exist");
    comments[_tweetId].push(Comment({
        id: nextCommentId,
        tweetId: _tweetId,
        author: msg.sender,
        content: _content,
        createdAt: block.timestamp
    }));
    
    emit Commented(msg.sender, _tweetId, nextCommentId);
    nextCommentId++;
}

 //set operator
    function setOperator(address _operator, address _user) external {
        require(msg.sender == _user, "You can only set operator for yourself");
        operators[_operator][_user] = true;
    }

    function deleteTweet(uint256 _tweetId) external {
    require(msg.sender == tweets[_tweetId].author || operators[msg.sender][tweets[_tweetId].author], "Only the author or an authorized operator can delete this tweet.");
    delete tweets[_tweetId];
    // Emit an event for the tweet deletion
    emit TweetDeleted(_tweetId);
}

function editTweet(uint256 _tweetId, string calldata _newContent) external {
    require(msg.sender == tweets[_tweetId].author || operators[msg.sender][tweets[_tweetId].author], "Only the author or an authorized operator can edit this tweet.");
    tweets[_tweetId].content = _newContent;
    // Emit an event for the tweet edit
    emit TweetEdited(_tweetId);
}
function unfollow(address _followed) external {
    // Find and remove _followed from the follower's list
    for (uint256 i = 0; i < following[msg.sender].length; i++) {
        if (following[msg.sender][i] == _followed) {
            following[msg.sender][i] = following[msg.sender][following[msg.sender].length - 1];
            following[msg.sender].pop();
            emit Unfollowed(msg.sender, _followed);
            return;
        }
    }
}

function blockUser(address _userToBlock) external {
    blocked[msg.sender][_userToBlock] = true;
    // Optionally, handle the removal of the blocked user from the follower's list
    emit UserBlocked(msg.sender, _userToBlock);
}
    function revokeOperator(address _operator) external {
    operators[_operator][msg.sender] = false;
    emit OperatorRevoked(_operator, msg.sender);
}



    
    function getConversation(address _from, address _to) external view returns(Message[] memory) {
        uint256 conversationId = generateConversationId(_from, _to);
        return conversations[conversationId];
    }


    function getFollowing(address _follower) external view returns(address[] memory) {
        return following[_follower];
    }

    function getLatestTweets(uint256 _count) external view returns(Tweet[] memory) {
        require(_count > 0 && _count < nextTweetId, "count can't be greater than nextTweetId");
        Tweet[] memory _tweets = new Tweet[](_count);
        for(uint256 i = nextTweetId - _count; i < nextTweetId; i++) {
            _tweets[i] = tweets[i];
        }
        return _tweets;
    }



    function getTweetsOf(address _author) external view returns(Tweet[] memory) {
        uint256[] memory tweetIds = tweetsOf[_author];
        Tweet[] memory _tweets = new Tweet[](tweetIds.length);
        for(uint256 i = 0; i < tweetIds.length; i++) {
            _tweets[i] = tweets[tweetIds[i]];
        }
        return _tweets;
    }

    function getTweetLikes(uint256 _tweetId) external view returns (uint256) {
    return tweetLikes[_tweetId].length;
}
function getRetweet(uint256 _retweetId) external view returns(uint256) {
    return retweets[_retweetId];
}


function getBlockedUsers(address _user) external view returns (address[] memory) {
    uint256 count = 0;
    // Count blocked users first to initialize the array with the correct size
    for(uint256 i = 0; i < following[_user].length; i++) {
        if (blocked[_user][following[_user][i]]) {
            count++;
        }
    }
    
    address[] memory blockedUsers = new address[](count);
    uint256 index = 0;
    for(uint256 i = 0; i < following[_user].length; i++) {
        if (blocked[_user][following[_user][i]]) {
            blockedUsers[index] = following[_user][i];
            index++;
        }
    }
    return blockedUsers;
}
   
    
}