import {GetList, GetListUsers, useAddItem, useDeleteItem, useInviteUser, useRevokeInvitation} from "./FETCHERS";
import {Button, Col, Container, Form, Row, Table} from "react-bootstrap";
import useUpdater from "./useUpdater";
import PageTitle from "./PageTitle";
import Loader from "./Loader";
import AddForm from "./AddForm";
import Authorized, {permInvoke, permWrite} from "./Authorized";
import {useRef} from "react";

const Item = ({updater, listData, itemData}) => {
    const del = useDeleteItem({list_id: listData.id, item_id: itemData.id}).mutate;
    const onDelete = updater.update(() => del()); // avoid event passing
    return (
        <tr>
            <td>{itemData.text}</td>
            <Authorized mode={listData.access} permission={permWrite}>
                <td>
                    <Button variant={"outline-danger"} disabled={updater.updating} onClick={onDelete}>удалить</Button>
                </td>
            </Authorized>
        </tr>
    );
}

const ItemsTable = ({updater, listData}) => {
    return (
        <div className="todolist">
            <Table className={"todolist-items"}>
                {listData.items.map(item => (
                    <Item listData={listData} itemData={item} updater={updater}/>
                ))}
            </Table>
        </div>
    )
};

const AddItem = ({updater, listId}) => {
    const addItem = useAddItem({list_id: listId});
    const onSubmit = updater.update(text => addItem.mutate({text: text}));
    return (<AddForm placeholder="Новый пункт"
                     submitText="Добавить пункт"
                     onSubmit={onSubmit}
                     disabled={updater.updating}
    />);
}

const User = ({updater, listData, userData}) => {
    const del = useRevokeInvitation({list_id: listData.id, user_id: userData.user_name}).mutate;
    const onDelete = updater.update(() => del());
    return (
        <tr>
            <td>{userData.user_name}</td>
            <Authorized mode={listData.access} permission={permInvoke}>
                <td>
                    <Button variant="outline-danger" disabled={updater.updating} onClick={onDelete}>Отозвать</Button>
                </td>
            </Authorized>
        </tr>
    );
}

const UsersTable = ({updater, listData}) => {
    return (
        <GetListUsers list_id={listData.id} queryParams={{_epoch: updater.epoch}}>{Loader(
            users => (
                <Table>{
                    users.filter(user => !user.me)
                        .map(user => (<User updater={updater} listData={listData} userData={user}/>))
                }</Table>
            )
        )}</GetListUsers>
    );
}

const AddUser = ({updater, listData}) => {
    const loginRef = useRef(null);
    const modeRef = useRef(null);
    const addUser = useInviteUser({list_id: listData.id}).mutate;
    const onSubmit = updater.update(() => addUser({
        access_mode: modeRef.current.value,
        invitee: loginRef.current.value
    }))
    return (<Form onSubmit={onSubmit} disabled={updater.updating} className={"add-form"}>
        <Form.Row>
            <Form.Group controlId="login" as={Col}>
                <Form.Control required type="text" placeholder="Логин пользователя" ref={loginRef}
                              disabled={updater.updating}/>
            </Form.Group>
            <Form.Group controlId="mode" as={Col}>
                <Form.Control as="select" ref={modeRef}>
                    <option value="R">Чтение</option>
                    <option value="RW">Чтение и запись</option>
                </Form.Control>
            </Form.Group>
            <Col>
                <Button variant="primary" type="submit" disabled={updater.updating}>Пригласить</Button>
            </Col>
        </Form.Row>
    </Form>);
}

const TODOList = ({match}) => {
    const listId = match.params.listId
    const itemsUpdater = useUpdater();
    const usersUpdater = useUpdater();
    return (<Container>
        <GetList list_id={listId} queryParams={{_epoch: itemsUpdater.epoch}}>{
            Loader(listData => (<>
                <Row><PageTitle title={listData.name}/></Row>
                <Row><ItemsTable updater={itemsUpdater} listData={listData}/></Row>
                <Authorized mode={listData.access} permission={permWrite}>
                    <Row><AddItem updater={itemsUpdater} listId={listId}/></Row>
                </Authorized>
                <Authorized mode={listData.access} permission={permInvoke}>
                    <Row><h1 className="section-title">Пользователи</h1></Row>
                    <Row><UsersTable updater={usersUpdater} listData={listData}/></Row>
                    <Row><AddUser updater={usersUpdater} listData={listData}/></Row>
                </Authorized>
            </>))
        }
        </GetList>
    </Container>);
};

export default TODOList;