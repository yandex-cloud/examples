CREATE TABLE `authorized_users`
(
    login   Utf8,
    PRIMARY KEY (login)
);
COMMIT;

-- insert @yandex.ru logins authorized to perform requests
-- INSERT INTO `authorized_users`
--     (login)
-- VALUES ("???");
-- COMMIT;