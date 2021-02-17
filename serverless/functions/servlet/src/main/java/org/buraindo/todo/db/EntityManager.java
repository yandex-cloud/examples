package org.buraindo.todo.db;

import com.yandex.ydb.auth.iam.CloudAuthProvider;
import com.yandex.ydb.core.grpc.GrpcTransport;
import com.yandex.ydb.table.TableClient;
import com.yandex.ydb.table.query.DataQueryResult;
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

    public void execute(String query, Consumer<DataQueryResult> callback) {
        var authProvider = CloudAuthProvider.newAuthProvider(ComputeEngineCredentialProvider.builder().build());
        var transport = GrpcTransport.forEndpoint(endpoint, database).withAuthProvider(authProvider).withSecureConnection().build();
        var tableClient = TableClient.newClient(GrpcTableRpc.useTransport(transport)).build();

        var session = tableClient.createSession()
                .join()
                .expect("Error: can't create session");

        var result = session.executeDataQuery(query, TxControl.serializableRw().setCommitTx(true))
                .join()
                .expect("Error: query failed");

        if (callback != null) {
            callback.accept(result);
        }

    }

    public void execute(String query) {
        execute(query, null);
    }

}
