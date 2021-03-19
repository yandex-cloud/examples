package yandex.cloud.examples.serverless.todo;

import yandex.cloud.examples.serverless.todo.db.Dao;
import yandex.cloud.examples.serverless.todo.db.TaskDao;
import yandex.cloud.examples.serverless.todo.model.Task;

import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.util.Objects;

public class AddTaskServlet extends HttpServlet {

    private final Dao<Task> taskDao = new TaskDao();

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) {
        var name = req.getParameter("name");
        Objects.requireNonNull(name, "Parameter 'name' missing");

        var description = req.getParameter("description");
        Objects.requireNonNull(description, "Parameter 'description' missing");

        taskDao.save(new Task(name, description));
    }

}
