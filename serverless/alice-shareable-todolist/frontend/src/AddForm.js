import {Button, Col, Form} from "react-bootstrap";
import React, {useRef} from "react";
import "./AddForm.css"

const AddForm = ({disabled, placeholder, submitText, onSubmit}) => {
    const inputRef = useRef(null);
    const realSubmit = () => onSubmit(inputRef.current.value);
    return (
        <Form className="add-form" onSubmit={realSubmit} disabled={disabled}>
            <Form.Row>
                <Form.Group controlId="name" as={Col}>
                    <Form.Control required type="text" placeholder={placeholder} ref={inputRef} disabled={disabled}/>
                </Form.Group>
                <Col>
                    <Button disabled={disabled} variant="primary" type="submit">{submitText}</Button>
                </Col>
            </Form.Row>
        </Form>
    )
};

export default AddForm;