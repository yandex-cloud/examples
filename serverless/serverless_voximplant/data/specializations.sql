CREATE TABLE `specializations`
(
    id   Utf8,
    name Utf8,
    PRIMARY KEY (id, name)
);
COMMIT;

INSERT INTO `specializations`
    (id, name)
VALUES ("A28A6D69362B", "терапевт"),
       ("C114F6DCBF50", "хирург"),
       ("27841926AAE0", "отоларинголог"),
       ("3C36FBC3A5E5", "офтальмолог");
COMMIT;