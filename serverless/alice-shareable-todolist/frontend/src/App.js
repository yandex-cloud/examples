import React from "react";
import {RestfulProvider} from "restful-react";
import MyLists from "./MyLists";
import {HashRouter, NavLink, Route} from "react-router-dom";
import {Navbar} from "react-bootstrap";
import UserBadge from "./UserBadge";
import TODOList from "./TODOList";
import "./App.css"

const App = () => (
    <RestfulProvider base="/" onError={onAPIError}>
        <HashRouter>
            <Navbar>
                <div className="container d-flex justify-content-between">
                    <div className="navigation-links">
                        <NavLink className="nav-link" to="/">Мои списки</NavLink>
                    </div>
                    <UserBadge/>
                </div>
            </Navbar>
            <div className="page-content">
                <Route exact path="/" component={MyLists}/>
                <Route exact path="/lists/:listId" component={TODOList}/>
            </div>
        </HashRouter>
    </RestfulProvider>
);

function onAPIError(err) {
    if (err.status === 401) {
        document.location = "/login"
    }
}

export default App;