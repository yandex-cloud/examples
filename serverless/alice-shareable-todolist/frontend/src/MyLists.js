import React, {useRef} from "react";
import "./FETCHERS"
import {ListLists, useAcceptInvitation, useCreateList, useDeleteList} from "./FETCHERS";
import {Button, Col, Container, Form, Row, Table} from "react-bootstrap";
import {NavLink} from "react-router-dom";
import useUpdater from "./useUpdater";
import Loader from "./Loader";
import PageTitle from "./PageTitle";
import AddForm from "./AddForm";

const ListItem = ({list, updater}) => {
    const del = useDeleteList({list_id: list.id}).mutate;
    const onDelete = updater.update(() => del()); // avoid event passing
    return (
        <tr>
            <td><NavLink to={"/lists/" + list.id}>{list.name}</NavLink></td>
            <td><Button disabled={updater.updating} variant={"outline-danger"} onClick={onDelete}>удалить</Button></td>
        </tr>
    );
}

const CreateListForm = ({updater}) => {
    const create = useCreateList();
    const onSubmit = updater.update(name => create.mutate({name: name}));
    return (<AddForm placeholder="Название списка"
                     submitText="Создать список"
                     onSubmit={onSubmit}
                     disabled={updater.updating}
    />);
}

const ListsTable = ({updater, lists}) => {
    if (lists.length === 0) {
        return (<div>У вас пока нет списков</div>);
    }
    return (<Table>
        <tbody>
        {lists.map(list => (<ListItem list={list} updater={updater}/>))}
        </tbody>
    </Table>);
};

const InvitationItem = ({updater, listData}) => {
    const reject = useDeleteList({list_id: listData.id}).mutate;
    const onReject = updater.update(() => reject());
    const accept = useAcceptInvitation({list_id: listData.id}).mutate;
    const aliasRef = useRef(null);
    const onAccept = updater.update(() => accept({alias: aliasRef.current.value}));
    return (
        <Form>
            <Form.Row>
                <Form.Group controlId="alias" as={Col}>
                    <Form.Control required type="text" placeholder="Название списка" ref={aliasRef}
                                  defaultValue={listData.name} disabled={updater.updating}/>
                </Form.Group>
                <Col> <Form.Text>от пользователя {listData.inviter}</Form.Text> </Col>
                <Col>
                    <Button variant="primary" disabled={updater.updating} onClick={onAccept}>принять</Button>
                    <Button variant="outline-danger" disabled={updater.updating}
                            onClick={onReject}>отклонить</Button>
                </Col>
            </Form.Row>
        </Form>
    );
}

const Invitations = ({updater, lists}) => (
    <Container>
        {lists.map(list => (<Row><InvitationItem updater={updater} listData={list}/></Row>))}
    </Container>
);

const MyLists = () => {
    const updater = useUpdater();
    return (<Container>
        <Row>
            <PageTitle title={"Мои списки"}/>
        </Row>
        <ListLists queryParams={{_epoch: updater.epoch}}>{
            Loader((lists) => {
                const accepted = lists.filter(l => l.accepted);
                const invitations = lists.filter(l => !l.accepted);
                return (<>
                    <Row>
                        <ListsTable updater={updater} lists={accepted}/>
                    </Row>
                    <Row>
                        <CreateListForm updater={updater}/>
                    </Row>
                    {invitations.length > 0
                        ?
                        <>
                            <Row>
                                <h1 className="section-title">Приглашения</h1>
                            </Row>
                            <Row>
                                <Invitations updater={updater} lists={invitations}/>
                            </Row>
                        </>
                        : ""
                    }
                </>);
            })
        }</ListLists>
    </Container>);
}

export default MyLists;