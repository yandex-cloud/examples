package yandex.cloud.examples.serverless.todo.db;

import com.yandex.ydb.table.query.Params;
import com.yandex.ydb.table.values.PrimitiveValue;
import yandex.cloud.examples.serverless.todo.model.Task;
import yandex.cloud.examples.serverless.todo.utils.ThrowingConsumer;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

public class TaskDao implements Dao<Task> {

    private final EntityManager entityManager = new EntityManager(System.getenv("DATABASE"), System.getenv("ENDPOINT"));

    @Override
    public List<Task> findAll() {
        var tasks = new ArrayList<Task>();
        entityManager.execute("select * from Tasks", Params.empty(), ThrowingConsumer.unchecked(result -> {
            var resultSet = result.getResultSet(0);
            while (resultSet.next()) {
                tasks.add(Task.fromResultSet(resultSet));
            }
        }));
        return tasks;
    }

    @Override
    public void save(Task task) {
        entityManager.execute(
                "declare $taskId as Utf8;" +
                        "declare $name as Utf8;" +
                        "declare $description as Utf8;" +
                        "insert into Tasks(TaskId, Name, Description, CreatedAt) values ($taskId, $name, $description, CurrentUtcDateTime())",
                Params.of("$taskId", PrimitiveValue.utf8(UUID.randomUUID().toString()),
                        "$name", PrimitiveValue.utf8(task.getName()),
                        "$description", PrimitiveValue.utf8(task.getDescription()))
        );
    }

    @Override
    public void deleteById(String taskId) {
        entityManager.execute(
                "declare $taskId as Utf8;" +
                        "delete from Tasks where TaskId = $taskId",
                Params.of("$taskId", PrimitiveValue.utf8(taskId)));
    }

}
