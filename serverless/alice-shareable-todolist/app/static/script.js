$(document).ready(function () {
    applyTemplates();
});

function applyTemplates() {
    applyTODOListsListItem();
    applyIncomingInvitationsItem();
    applyUserBadge();
    applyTODOList();
    applyMenu();
}

function applyMenu() {
    $(".menu").each(function () {
        let $e = $(this);
        let items = [
            {url: "/", name: "Мои списки"},
        ];
        for (let i = 0; i < items.length; i++) {
            let item = items[i];
            $e.append($("<a/>", {
                class: "menu_item",
                href: item.url,
                text: item.name,
            }))
        }
    });
}

function applyTODOListsListItem() {
    $(".todo-lists_item").each(function () {
        $e = $(this);
        let data = getData($e);
        $href = $('<a/>', {
            href: "/list?" + $.param({"id": data.ID}),
            text: data.Name,
            class: "todo-lists_item-href",
        });
        $drop = listButton().addClass("todo-lists_item-drop")
            .click(submitCallback({
                url: "/api/delete-list",
                params: {list_id: data.ID}
            }));
        $e.empty();
        $e.append($href, $drop);
    });
}

function applyIncomingInvitationsItem() {
    $(".incoming-invitations_item").each(function () {
        $e = $(this);
        let data = getData($e);

        let $inviteForm = $('<form class="accept-invitation-form" action="/api/accept-invitation">').append(
            hiddenInput("list_id", data.ID),
            textInput({name: "alias", value: data.Name}).addClass("accept-invitation-form_alias"),
            $('<span/>', {class: "accept-invitation-form_inviter", text: data.InviterName}),
            $('<span/>', {class: "accept-invitation-form_access accept-invitation-form_access__" + data.Access}),
            formButton("принять").addClass("accept-invitation-form_submit"),
            listButton().addClass("accept-invitation-form_reject")
                .click(submitCallback({
                    url: "/api/reject-invitation",
                    params: {list_id: data.ID}
                }))
        ).submit(submitAjax);

        $e.empty();
        $e.append($inviteForm);
    });
}

function applyUserBadge() {
    $(".user-badge").each(function () {
        let $e = $(this);
        let data = getData($e);
        let $name = $('<span/>', {
            class: 'user-badge_name',
            text: data.Name,
        });
        let $avatar = $('<span/>', {
            class: 'user-badge_avatar',
        });
        $avatar.css(
            'background-image', 'url(https://avatars.yandex.net/get-yapic/' + data.YandexAvatarID + '/islands-50)'
        );
        $e.empty();
        $e.append($name, $avatar);
    });
}

function applyTODOList() {
    $(".todo-list").each(function () {
        let $e = $(this);
        let data = getData($e);

        let $mainItems = $('<ul/>', {class: "todo-list-main_items"});
        let $mainSection = section().addClass("todo-list-main").append($mainItems);

        let $usersTitle = sectionHeading("Пользователи").addClass('todo-list-users_title');
        let $users = $('<ul/>', {class: "todo-list-users_items"});
        let $usersSection = section().addClass("todo-list-users").append($usersTitle, $users);

        let $invitationsTitle = sectionHeading("Приглашения").addClass('todo-list-invitations_title');
        let $invitations = $('<ul/>', {class: "todo-list-invitations_items"});
        let $invitationsSection = section().addClass("todo-list-invitations").append($invitationsTitle, $invitations);

        for (let i = 0; i < data.Items.length; i++) {
            let itemData = data.Items[i];
            let $item = $('<li/>', {
                class: "todo-list-main_item",
                'data-json': JSON.stringify(itemData),
            });
            let $itemText = $('<span/>', {
                class: "todo-list_item-text",
                text: itemData.Text,
            });
            $item.append($itemText);
            $mainItems.append($item);
        }

        if (!data.Users) {
            $usersSection.addClass("hidden")
        } else {
            for (let i = 0; i < data.Users.length; i++) {
                let userData = data.Users[i];
                let $user = $('<li/>', {
                    class: "todo-list-users_user",
                    'data-json': JSON.stringify(userData),
                });
                let $userName = $('<span/>', {
                    class: "todo-list-users_user-name",
                    text: userData.UserName,
                });
                let $userAccess = $('<span/>', {
                    class: "todo-list-users_user-access access-mode__" + userData.Mode,
                });
                let $userDrop = listButton().addClass("todo-list-users_user-drop")
                    .click(submitCallback({
                        url: "/api/revoke-invitation",
                        params: {list_id: data.ID, invitee: userData.UserName}
                    }));
                $user.append($userName, $userAccess, $userDrop);
                $users.append($user);
            }
        }

        if (!data.Invitations) {
            $invitationsSection.addClass("hidden")
        } else {
            for (let i = 0; i < data.Invitations.length; i++) {
                let userData = data.Invitations[i];
                let $user = $('<li/>', {
                    class: "todo-list-invitations_user",
                    'data-json': JSON.stringify(userData),
                });
                let $userName = $('<span/>', {
                    class: "todo-list-invitations_user-name",
                    text: userData.UserName,
                });
                let $userAccess = $('<span/>', {
                    class: "todo-list-invitations_user-access access-mode__" + userData.Mode,
                });
                let $itemDrop = listButton().addClass("todo-list-invitations_user-drop")
                    .click(submitCallback({
                        url: "/api/revoke-invitation",
                        params: {list_id: data.ID, invitee: userData.UserName}
                    }));
                $user.append($userName, $userAccess, $itemDrop);
                $invitations.append($user);
            }
        }

        let $inviteForm = $('<form class="invite-user-form" action="/api/invite">').append(
            hiddenInput("list_id", data.ID),
            textInput({name: "invitee", placeholder: "пользователь"}).addClass("invite-user-form_user"),
            accessSelector("access").addClass("invite-user-form_access"),
            formButton("пригласить").addClass("invite-user-form_submit"),
        ).submit(submitAjax);
        if (!data.OwnedByMe) {
            $inviteForm.addClass("hidden");
        }

        $e.empty();
        $e.append($mainSection, $usersSection, $invitationsSection, $inviteForm);
    });
}

function submitCallback(req) {
    return function () {
        $.ajax({
            type: "POST",
            url: req.url + "?" + $.param(req.params),
            success: function (data) {
                document.location.reload();
            },
            error: function (err) {
                reportError(err.responseText);
            }
        });
    };
}

function submitAjax(e) {
    e.preventDefault();
    var form = $(this);
    var url = form.attr('action');

    $.ajax({
        type: "POST",
        url: url + "?" + form.serialize(),
        success: function (data) {
            document.location.reload();
        },
        error: function (err) {
            reportError(err.responseText);
        }
    });
}

function getData($e) {
    return $.parseJSON($e.attr('data-json'));
}

function sectionHeading(title) {
    return $('<h2/>', {class: "section-title", text: title});
}

function section() {
    return $('<div/>', {class: "section"});
}

function listButton(mod) {
    if (!mod) {
        mod = "red"
    }
    return $('<span/>', {class: "list-button list-button__" + mod});
}

function textInput(data) {
    return $('<input/>', {
        type: "text",
        class: "text-input",
        placeholder: data.placeholder,
        name: data.name,
        val: data.value,
    });
}

function accessSelector(fieldName) {
    let $select = $('<select/>', {
        class: "access-selector",
        name: fieldName,
    });
    $select.append($(
        '<option selected value="RW" class="access-selector_RW">Чтение и редактирование</option>' +
        '<option value="R" class="access-selector_R">Только чтение</option>'
    ));
    return $select;
}

function hiddenInput(fieldName, value) {
    return $('<input/>', {
        type: "hidden",
        name: fieldName,
        val: value,
    })
}

function formButton(text) {
    return $('<input/>', {
        type: "submit",
        class: "form-button",
        value: text,
    })
}

function reportError(msg) {
    console.log(msg);
    alert(msg)
}