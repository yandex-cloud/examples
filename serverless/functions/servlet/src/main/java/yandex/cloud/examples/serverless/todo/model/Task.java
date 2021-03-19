package yandex.cloud.examples.serverless.todo.model;

import com.yandex.ydb.table.result.ResultSetReader;

public class Task {

    private String taskId;
    private String name;
    private String description;

    public Task(String name, String description) {
        this.name = name;
        this.description = description;
    }

    public Task(String taskId, String name, String description) {
        this.taskId = taskId;
        this.name = name;
        this.description = description;
    }

    public String getTaskId() {
        return taskId;
    }

    public void setTaskId(String taskId) {
        this.taskId = taskId;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public static Task fromResultSet(ResultSetReader resultSet) {
        var taskId = resultSet.getColumn("TaskId").getUtf8();
        var name = resultSet.getColumn("Name").getUtf8();
        var description = resultSet.getColumn("Description").getUtf8();
        return new Task(taskId, name, description);
    }

}
