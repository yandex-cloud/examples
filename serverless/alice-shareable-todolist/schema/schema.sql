CREATE TABLE `user`
(
    id string,
    name utf8,
    yandex_avatar_id string,
    PRIMARY KEY (id)
);

CREATE TABLE `todolist_acl`
(
    user_id string,
    mode string,
    list_id string,
    alias utf8,
    accepted bool,
    inviter string,
    PRIMARY KEY (list_id, user_id),
    INDEX UserToListACL GLOBAL ON (user_id)
);

CREATE TABLE `todolist`
(
    id string,
    owner_user_id string,
    items Json,
    PRIMARY KEY (id)
);

COMMIT;