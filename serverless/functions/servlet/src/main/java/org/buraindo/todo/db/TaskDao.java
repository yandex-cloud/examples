package org.buraindo.todo.db;

import org.buraindo.todo.model.Task;
import org.buraindo.todo.utils.ThrowingConsumer;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

public class TaskDao implements Dao<Task> {

    private final EntityManager entityManager = new EntityManager(System.getenv("DATABASE"), System.getenv("ENDPOINT"));

    @Override
    public List<Task> findAll() {
        var tasks = new ArrayList<Task>();
        entityManager.execute("select * from Tasks", ThrowingConsumer.unchecked(result -> {
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
                String.format(
                        "insert into Tasks(TaskId, Name, Description, CreatedAt) values ('%s', '%s', '%s', CurrentUtcDateTime())",
                        UUID.randomUUID().toString(),
                        task.getName(),
                        task.getDescription()
                )
        );
    }

    @Override
    public void deleteById(String taskId) {
        entityManager.execute(String.format("delete from Tasks where TaskId = '%s'", taskId));
    }

}
