package StorjLib.CallbackWrappers;

import android.util.Log;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;

import java.util.Arrays;

import StorjLib.GsonSingle;
import StorjLib.Models.BucketModel;
import StorjLib.Responses.Response;
import StorjLib.Responses.SingleResponse;
import StorjLib.StorjTypesWrappers.BucketWrapper;
import io.storj.libstorj.Bucket;
import io.storj.libstorj.GetBucketsCallback;

/**
 * Created by Crawter on 22.02.2018.
 */

public class GetBucketsCallbackWrapper implements GetBucketsCallback {
    private static final String TAG = "GetBucketsCallbackWrapp";

    private static final String E_GET_BUCKETS = "E_GET_BUCKETS";
    private Promise _promise;

    public GetBucketsCallbackWrapper(Promise promise) {
        _promise = promise;
    }

    @Override
    public void onBucketsReceived(Bucket[] buckets) {
        _promise.resolve(new SingleResponse(true, toJson(toBucketModelArray(buckets)), null).toWritableMap());
    }

    @Override
    public void onError(int code, String message) {
        _promise.reject(E_GET_BUCKETS, message);
    }

    private BucketModel[] toBucketModelArray(Bucket[] buckets) {
        int length = buckets.length;
        BucketModel[] result = new BucketModel[length];

        for(int i = 0; i < length; i++) {
            result[i] = new BucketModel(buckets[i]);
        }

        return result;
    }

    private String toJson(BucketModel[] convertible) {
        return GsonSingle.getInstanse().toJson(convertible);
    }
}
