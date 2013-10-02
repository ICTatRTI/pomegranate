/*
Copyright (C) 2011 by Pierre-Yves Orban

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

cordova.define("cordova/plugin/smssendingplugin", function(require, exports, module) {
  var exec = require('cordova/exec');
  var SmsSendingPlugin = function() {};

  /**
   * Check if the device has a possibility to send and receive SMS
   */
  SmsSendingPlugin.prototype.isSupported = function(successCallback,failureCallback) {
    return exec(successCallback, failureCallback, 'SmsSendingPlugin', 'HasSMSPossibility', []);
  }
  /**
   * Send a message to the given phone number
   * Rewritten by mike for nicer syntax
   */
  SmsSendingPlugin.prototype.send = function(options) {
    return exec(options.success, options.error, 'SmsSendingPlugin', 'SendSMS', [options.to, options.message]);
  }

  SmsSendingPlugin.prototype.oldSend = function(phone, message, successCallback,failureCallback) {
    return exec(successCallback, failureCallback, 'SmsSendingPlugin', 'SendSMS', [phone, message]);
  }

  var smssendingplugin = new SmsSendingPlugin();
  module.exports = smssendingplugin;
});
