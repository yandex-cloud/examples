package yandex.cloud.examples.serverless.todo;

import com.jsoniter.output.JsonStream;
import yandex.cloud.examples.serverless.todo.db.Dao;
import yandex.cloud.examples.serverless.todo.db.TaskDao;
import yandex.cloud.examples.serverless.todo.model.Task;

import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

public class ListTasksServlet extends HttpServlet {

    private final Dao<Task> taskDao = new TaskDao();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        var tasks = taskDao.findAll();
        var tasksJsonString = JsonStream.serialize(tasks);

        resp.setContentType("application/json");
        resp.setCharacterEncoding("UTF-8");
        
        var out = resp.getWriter();
        
        out.print(tasksJsonString);
        out.flush();
    }

}
