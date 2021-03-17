import {useState} from "react";

function useUpdater() {
    const [epoch, setEpoch] = useState(0);
    const [updating, setUpdating] = useState(false);
    return {
        epoch: epoch,
        updating: updating,
        update: (mutator) => {
            return (...args) => {
                if (updating) {
                    return;
                }
                setUpdating(true);
                mutator(...args).then(
                    () => {
                        setEpoch(e => e + 1);
                        setUpdating(false);
                    },
                    () => setUpdating(false)
                );
            }
        }
    };
}

export default useUpdater;