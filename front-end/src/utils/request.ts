import api from '../services/api';

const request = (config: any) => {
    return api(config);
};

export default request;
