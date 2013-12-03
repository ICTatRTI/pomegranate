package net.webootu.cordova.plugin;

import org.apache.cordova.api.CallbackContext;
import org.apache.cordova.api.CordovaPlugin;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.content.ContentResolver;
import android.database.Cursor;
import android.net.Uri;
import android.util.Log;

/**
 * Most Cordova plugins have all their functionality in one file, therefore the same
 * pattern will be applied here. execute(...) method will be delegating to other
 * private methods, based on action.
 * Some ideas from this Stack Overflow post:
 * {@link http://stackoverflow.com/questions/5946262/read-only-specificonly-from-particular-number-inbox-messages-and-display-throu}
 */
public class ReadSms extends CordovaPlugin {
    private static final String TAG = "ReadSmsPlugin";
    private static final String GET_TEXTS_ACTION = "GetTexts";
    private static final String GET_TEXTS_AFTER  = "GetTextsAfter";

    // Defaults:
    private static final Integer READ_ALL = -1;

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        Log.d(TAG, "Inside ReadSms plugin.");

        JSONObject result = new JSONObject();

        if (args.length() == 0) {
            result.put("error", "No phone number provided.");
            callbackContext.success(result);
            return false;
        }

        String phoneNumber = args.getString(0);
        result.put("phone_number", phoneNumber);

        if (action.equals("") || action.equals(GET_TEXTS_ACTION)) {
            return getAllTexts(args, callbackContext, result, phoneNumber);
        } else if (action.equals(GET_TEXTS_AFTER)) {
            return getTextsAfter(callbackContext, phoneNumber, args, result);
        } else {
            Log.e(TAG, "Unknown action provided.");
            result.put("error", "Unknown action provided.");
            callbackContext.success(result);
            return false;
        }
    }

    private boolean getTextsAfter( CallbackContext callbackContext,
            String phoneNumber, JSONArray args,    JSONObject result) throws JSONException {
        Log.d(TAG, "Read texts after timestamp.");

        if (args.length() < 2) {
            Log.e(TAG, "Time stamp is not provided.");
            result.put("error", "No timestamp provided.");
            callbackContext.success(result);
            return false;
        }

        String timeStamp = args.getString(1);
        if (!isNumeric(timeStamp)) {
            Log.e(TAG, "Time stamp provided is non-numeric.");
            result.put("error",
                String.format("Time stamp provided (%s) is non-numeric.", timeStamp));
            callbackContext.success(result);
            return false;
        } else if (timeStamp.startsWith("-") || timeStamp.startsWith("-")) {
            // isNumeric(...) corner case
            timeStamp = timeStamp.substring(1, timeStamp.length() - 1);
        }

        Log.d(TAG, String.format(
            "Querying for number %s with texts received after %s time stamp.",
            phoneNumber, timeStamp));
        JSONArray readResults = readTextsAfter( timeStamp );
        Log.d(TAG, "Read results received: " + readResults.toString());

        result.put("msgs", readResults);
        callbackContext.success(result);
        return true;
    }

    private boolean getAllTexts(JSONArray args, CallbackContext callbackContext,
            JSONObject result, String phoneNumber) throws JSONException {

        JSONArray readResults = readAllTexts();
        Log.d(TAG, "JOSH read results: " + readResults.toString());
        result.put("msgs", readResults);
        callbackContext.success(result);
        return true;
    }

    private JSONArray readAllTexts() throws JSONException {
        ContentResolver contentResolver = cordova.getActivity().getContentResolver();

        String sortOrder = "date DESC";

        Cursor cursor = contentResolver.query(Uri.parse("content://sms/inbox"), null,null,null,null);

        JSONArray results = new JSONArray();
        while (cursor.moveToNext()) {
            JSONObject current = new JSONObject();
            try {
                current.put("from",          cursor.getString(cursor.getColumnIndex("address")));
                current.put("time_received", cursor.getString(cursor.getColumnIndex("date")));
                current.put("message",       cursor.getString(cursor.getColumnIndex("body")));
                Log.d(TAG, "MSG found: time: " + cursor.getString(cursor.getColumnIndex("date"))
                        + " message: " + cursor.getString(cursor.getColumnIndex("body")));
            } catch (JSONException e) {
                e.printStackTrace();
                current.put("error", new String("Error reading text"));
            }
            results.put(current);
        }

        return results;
    }

    private JSONArray readTextsAfter( String timeStamp
            ) throws JSONException {
        ContentResolver contentResolver = cordova.getActivity().getContentResolver();
        String[] queryData = new String[] { timeStamp };

        String sortOrder = "date DESC";

        Cursor cursor = contentResolver.query(Uri.parse("content://sms/inbox"), null,
            "date>=?", queryData, sortOrder);

        JSONArray results = new JSONArray();
        while (cursor.moveToNext()) {
            JSONObject current = new JSONObject();
            try {
                current.put("from", cursor.getString(cursor.getColumnIndex("address")));
                current.put("time_received", cursor.getString(cursor.getColumnIndex("date")));
                current.put("message", cursor.getString(cursor.getColumnIndex("body")));
                Log.d(TAG, "time: " + cursor.getString(cursor.getColumnIndex("date"))
                    + " message: " + cursor.getString(cursor.getColumnIndex("body")));
            } catch (JSONException e) {
                e.printStackTrace();
                Log.e(TAG, "Error reading text", e);
                current.put("error", new String("Error reading text(s)."));
            }
            results.put(current);
        }

        Log.d(TAG, "Before returning results");
        return results;
    }

    /**
     * From Rosetta code: {@link http://rosettacode.org/wiki/Determine_if_a_string_is_numeric#Java}
     * @param inputData
     * @return
     */
    private static boolean isNumeric(String inputData) {
         return inputData.matches("[-+]?\\d+(\\.\\d+)?");
    }
}
