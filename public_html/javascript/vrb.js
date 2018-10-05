function doVrbAuth(vrbUrl) {
    var creds = {};
    getCreds(creds);
    
    var authUrl = vrbUrl + '/scheduler/extern_auth?callback=?'
    
    var queryString = 'user=' + creds.user + '&password=' + encodeURIComponent(creds.pass);
    var authed;
    $.getJSON(authUrl,queryString, function (res) {
        return true;
    });
    
    return false;
}

function getCreds(creds) {
    var url = "/vrb/getCreds.php";
    $.ajax({
        url: url,
        async: false,
        success: function(data) {
            creds.user = data.user
            creds.pass = data.pw;
        }
    })
}