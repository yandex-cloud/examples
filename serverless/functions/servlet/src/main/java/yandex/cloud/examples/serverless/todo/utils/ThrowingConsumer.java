package yandex.cloud.examples.serverless.todo.utils;

import java.util.function.Consumer;

@FunctionalInterface
public interface ThrowingConsumer<T, E extends Throwable> {
    void accept(T input) throws E;

    static <T, E extends Throwable> Consumer<T> unchecked(final ThrowingConsumer<T, E> consumer) {
        return t -> {
            try {
                consumer.accept(t);
            } catch (final Throwable e) {
                throw new RuntimeException(e);
            }
        };
    }
}
