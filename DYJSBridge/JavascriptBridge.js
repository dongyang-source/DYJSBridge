JSBridge = {
    responseCallbacks: {},
    uniqueId: 1,
    // native call js
    handleMessageFromObjC: function(messageJSON) {
        var message = JSON.parse(messageJSON);
        var responseCallback;
        var messageHandler;

        if (message.responseId) {
            responseCallback = this.responseCallbacks[message.responseId];
            if (responseCallback) {
                responseCallback(message.data);
                delete this.responseCallbacks[message.responseId];
            }
        } else {
            var callbackResponseId = message.callbackId;
            if (callbackResponseId) {
                responseCallback = function(responseData) {
                    var message = {
                        'responseId': callbackResponseId,
                        'arguments': responseData
                    };
                    window.webkit.messageHandlers.webViewApp.postMessage(message);
                };
            }
            if (message.handlerName) { //call by functionName
                try {
                    var arr = message.handlerName.split('.');
                    var obj = window;
                    var itemName = arr[0];
                    var i = 1;
                    if(itemName == "window") {
                        itemName = arr[1];
                        i = 2;
                    }
                    for (; i < arr.length; i++) {
                        obj = obj[itemName];
                        itemName = arr[i];
                    }
                    return obj[itemName](message.data, responseCallback);
                } catch (error) {

                }
            }
        }
    },
    // js call native
    callHandler: function(name, handlerName, data, responseCallback) {
        if (arguments.length == 3 && typeof data == 'function') {
            responseCallback = data;
            data = null;
        }
        var message = {
            'handlerName': handlerName,
            'name': name
        };
        if (data) {
            if (typeof data == 'string') {
                try {
                    data = JSON.parse(data);
                } catch (error) {}
            }
            message['arguments'] = data;
        }
        if (responseCallback) {
            var callbackId = 'cb_' + (this.uniqueId++) + '_' + new Date().getTime();
            this.responseCallbacks[callbackId] = responseCallback;
            message['callbackId'] = callbackId;
        }
        window.webkit.messageHandlers.webViewApp.postMessage(message);
    }
};
