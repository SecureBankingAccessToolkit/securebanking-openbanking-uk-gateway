import groovy.json.JsonOutput
import org.forgerock.http.MutableUri

def fapiInteractionId = request.getHeaders().getFirst("x-fapi-interaction-id");
if(fapiInteractionId == null) fapiInteractionId = "No x-fapi-interaction-id";
SCRIPT_NAME = "[RepoUser] (" + fapiInteractionId + ") - ";
logger.debug(SCRIPT_NAME + "Running...")

// Fetch the API Client from IDM
Request userRequest = new Request();
userRequest.setMethod('GET');

// response object
response = new Response(Status.OK)
response.headers['Content-Type'] = "application/json"

// get uri query filter
def uriQuery = new MutableUri(request.uri).getQuery()
// get uri path elements
def uriPathElements =  new MutableUri(request.uri).getPathElements()
logger.debug(SCRIPT_NAME + "uriFilter: {}, splitUriPath: {}", uriQuery, uriPathElements)
// validate uri path
if (uriPathElements.length == 0) {
    message = "Can't parse URI from inbound request"
    logger.error(SCRIPT_NAME + message)
    response.status = Status.BAD_REQUEST
    response.entity = "{ \"error\":\"" + message + "\"}"
    return response
}

Boolean queryFilter = false
// condition IDM request to retrieve the user data by user name or by user ID
if(uriQuery.length == 2){
    logger.debug(SCRIPT_NAME + "Looking up API User by filter {}", uriQuery[uriQuery.length -1])
    userRequest.setUri(routeArgIdmBaseUri + "/openidm/managed/" + routeArgObjUser + "?" + uriQuery[uriQuery.length -1])
    queryFilter = true
} else {
    logger.debug(SCRIPT_NAME + "Looking up API User by user ID {}", uriPathElements[uriPathElements.length - 1])
    userRequest.setUri(routeArgIdmBaseUri + "/openidm/managed/" + routeArgObjUser + "/" + uriPathElements[uriPathElements.length - 1])
}

/*
 examples to test the filter. It needs to be run from a container:
 - curl -i -v http://ig:80/repo/users?_queryFilter=userName+eq+%22<Cloud platform user name>%22
 - curl -i -v http://ig:80/repo/users/<Cloud platform user ID>
 */

http.send(userRequest).then(userResponse -> {
    userRequest.close()
    logger.debug(SCRIPT_NAME + "Back from IDM")

    def userResponseStatus = userResponse.getStatus();
    logger.debug(SCRIPT_NAME + " status {}", userResponseStatus)

    if (userResponseStatus != Status.OK) {
        return errorResponse("User details not found", userResponseStatus)
    }

    def userResponseContent = userResponse.getEntity()

    logger.debug(SCRIPT_NAME + "response JSON {}", userResponseContent.getJson().result)

    // build response Object
    def userResponseObject = userResponseContent.getJson()
    if(queryFilter){
        if(userResponseContent.getJson().result.isEmpty()){
            return errorResponse("User details not found", Status.NOT_FOUND)
        }
        userResponseObject = userResponseContent.getJson().result[0]
    }

    def responseObj = [
            "id": userResponseObject._id,
            "userName": userResponseObject.userName,
            "givenName": userResponseObject.givenName,
            "surname": userResponseObject.sn,
            "mail": userResponseObject.mail,
            "accountStatus": userResponseObject.accountStatus
    ]

    def responseJson = JsonOutput.toJson(responseObj)
    logger.debug(SCRIPT_NAME + "Final JSON " + responseJson)

    response.entity = responseJson;
    return response

}).then(response -> { return response })

def errorResponse(String message, userResponseStatus) {
    logger.error(SCRIPT_NAME + message)
    response.status = userResponseStatus
    response.entity = "{ \"error\":\"" + message + "\"}"
    return response
}