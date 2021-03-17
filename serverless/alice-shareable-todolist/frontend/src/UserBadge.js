import {UserInfo} from "./FETCHERS";
import "./UserBadge.css"

const UserBadge = ({className}) => (
    <UserInfo>{response => (
        response
            ? <span className="user-badge">
                <span className="user-badge_name">{response.name}</span>
            <span className="user-badge_avatar" style={{
                'background-image': 'url(https://avatars.yandex.net/get-yapic/' + response.avatar_id + '/islands-50)'
            }}/>
            </span>
            : ""
    )}</UserInfo>
);

export default UserBadge;