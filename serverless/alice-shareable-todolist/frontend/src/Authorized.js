const Authorized = ({mode, permission, children}) => {
    let authorized = false
    switch (permission) {
        case permWrite:
            authorized = mode === "RW" || mode === "O";
            break
        case permInvoke:
            authorized = mode === "O";
            break
        default:
    }
    if (!authorized) {
        return (<></>)
    }
    return (<>{children}</>)
}

export default Authorized;
export const permWrite = "write";
export const permInvoke = "invoke";