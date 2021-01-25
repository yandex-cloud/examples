CREATE TABLE `places`
(
    id   Utf8,
    name Utf8,
    PRIMARY KEY (id, name)
);
COMMIT;

INSERT INTO `places`
    (id, name)
VALUES ("D8A35114835B", "Тухачевского, 15"),
       ("99989B8F9F1C", "Пушкинская, 10");
COMMIT;