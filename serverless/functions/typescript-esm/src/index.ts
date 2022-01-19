import fetch from 'node-fetch';

export const handler = async () => {
    const res = await fetch('https://example.com');
    return { 
        body: `https://example.com responded with status: ${res.status}` 
    };
}
