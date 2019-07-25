%@: function() {
        var responseCallback;
        var arr = new Array();
        let name = "%@";
        let handName = "%@";
        for (var i = 0; i < arguments.length; i++) {
            var item = arguments[i];
            if (typeof item == 'function') {
                responseCallback = item;
            } else {
                arr.push(item);
            }
        }
        if (arr.length > 0) {
            JSBridge.callHandler(name,handName, arr, responseCallback);
        } else {
            JSBridge.callHandler(name,handName, responseCallback);
        }
    }