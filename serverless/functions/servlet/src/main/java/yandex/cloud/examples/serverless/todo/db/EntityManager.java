package yandex.cloud.examples.serverless.todo.db;

import com.yandex.ydb.auth.iam.CloudAuthProvider;
import com.yandex.ydb.core.grpc.GrpcTransport;
import com.yandex.ydb.table.TableClient;
import com.yandex.ydb.table.query.DataQueryResult;
import com.yandex.ydb.table.query.Params;
import com.yandex.ydb.table.rpc.grpc.GrpcTableRpc;
import com.yandex.ydb.table.transaction.TxControl;
import yandex.cloud.sdk.auth.provider.ComputeEngineCredentialProvider;

import java.util.function.Consumer;

public class EntityManager {
    private final String database;
    private final String endpoint;

    public EntityManager(String database, String endpoint) {
        this.database = database;
        this.endpoint = endpoint;
    }

    public void execute(String query, Params params, Consumer<DataQueryResult> callback) {
        var authProvider = CloudAuthProvider.newAuthProvider(ComputeEngineCredentialProvider.builder().build());
        var transport = GrpcTransport.forEndpoint(endpoint, database).withAuthProvider(authProvider).withSecureConnection().build();
        var tableClient = TableClient.newClient(GrpcTableRpc.useTransport(transport)).build();

        var session = tableClient.createSession()
                .join()
                .expect("Error: can't create session");

        var preparedQuery = session.prepareDataQuery(query)
                .join()
                .expect("Error: query preparation failed");

        var result = preparedQuery.execute(TxControl.serializableRw().setCommitTx(true), params)
                .join()
                .expect("Error: query execution failed");

        if (callback != null) {
            callback.accept(result);
        }

    }

    public void execute(String query, Params params) {
        execute(query, params, null);
    }

}
