import {Spinner} from "react-bootstrap";

function Loader(content) {
    return response => {
        if (!response) {
            return (<Spinner animation={"grow"}/>);
        }
        return content(response);
    }
}

export default Loader;