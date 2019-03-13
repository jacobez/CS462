const axios = require('axios');
const _ = require('lodash');

const eci = 'HSqqQZV3jKGExBfyjCybpQ';
const baseURL = 'http://localhost:8080';

const newSensor = (name) => {
    return axios.post(`${baseURL}/sky/event/${eci}/1/sensor/new_sensor`, {
        name
    }).then((response) => {
        return response;
    });
}

const getSensors = () => {
    return axios.get(`${baseURL}/sky/cloud/${eci}/manage_sensors/sensors`).then(response => {
        return response.data;
    });
}

const deleteSensor = (name) => {
    return axios.post(`${baseURL}/sky/event/${eci}/1/sensor/unneeded_sensor`, {
        name
    }).then((response) => {
        return response;
    });
}

test('picos are created', async () => {
    await newSensor('Wovyn 1');
    await newSensor('Wovyn 2');
    const sensors = await getSensors();
    expect(_.has(sensors, 'Wovyn 1')).toBeTruthy();
    expect(_.has(sensors, 'Wovyn 2')).toBeTruthy();
})

test('picos are deleted', async () => {
    await deleteSensor('Wovyn 1');
    const sensors = await getSensors();
    expect(_.has(sensors, 'Wovyn 1')).toBeFalsy();
    expect(_.has(sensors, 'Wovyn 2')).toBeTruthy();
});