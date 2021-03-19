package yandex.cloud.examples.serverless.todo.db;

import java.util.List;

public interface Dao<T> {

    List<T> findAll();

    void save(T t);

    void deleteById(String id);

}