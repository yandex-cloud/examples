import {useEffect} from "react";
import "./PageTitle.css"

const PageTitle = ({title}) => {
    useEffect(() => document.title = "Списки Алисы - " + title);
    return (<h1 className="page-title section-title">{title}</h1>)
}

export default PageTitle