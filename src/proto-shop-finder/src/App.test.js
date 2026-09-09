import { act, fireEvent, render, screen } from '@testing-library/react';

const map = { relayout: jest.fn(), setCenter: jest.fn(), setBounds: jest.fn() };
function createMapSdk() { return {
  LatLng: jest.fn(function (latitude, longitude) { Object.assign(this, { latitude, longitude }); }),
  Map: jest.fn(() => map),
  Marker: jest.fn(function (options) { Object.assign(this, options, { setMap: jest.fn() }); }),
  InfoWindow: jest.fn(function (options) { Object.assign(this, options, { open: jest.fn() }); }),
  LatLngBounds: jest.fn(function () { this.extend = jest.fn(); }),
}; }
window.kakao = { maps: createMapSdk() };

const App = require('./App').default;
const firstShop = require('./datas/data').default[0];
const originalGeolocation = Object.getOwnPropertyDescriptor(navigator, 'geolocation');

beforeEach(() => {
  jest.clearAllMocks();
  window.kakao.maps = createMapSdk();
  jest.spyOn(console, 'log').mockImplementation(() => {});
  Object.defineProperty(navigator, 'geolocation', { configurable: true, value: {
    getCurrentPosition: jest.fn(success => success({ coords: { latitude: Number(firstShop.y), longitude: Number(firstShop.x) } })),
  } });
});

afterEach(() => {
  jest.restoreAllMocks();
  jest.useRealTimers();
});

afterAll(() => {
  if (originalGeolocation) Object.defineProperty(navigator, 'geolocation', originalGeolocation);
  else delete navigator.geolocation;
  delete window.kakao;
});

test('mounts the real map and all radius controls', () => {
  render(<App />);
  expect(screen.getByText('토방으로뛰어')).toBeInTheDocument();
  for (const radius of [1, 3, 5, 7, 10]) expect(screen.getByText(`반경 ${radius}KM`)).toBeInTheDocument();
  expect(window.kakao.maps.Map).toHaveBeenCalledWith(document.getElementById('map'), expect.objectContaining({ level: 3 }));
  expect(document.getElementById('map').style.height).toBe(`${window.innerHeight - 100}px`);
});

test('radius selection uses actual shop data and positions the location and shop markers', () => {
  render(<App />);
  fireEvent.click(screen.getByText('반경 1KM'));
  expect(navigator.geolocation.getCurrentPosition).toHaveBeenCalledTimes(1);
  expect(map.setCenter).toHaveBeenCalledWith(expect.objectContaining({ latitude: Number(firstShop.y), longitude: Number(firstShop.x) }));
  expect(window.kakao.maps.InfoWindow.mock.calls.some(([options]) => options.content.includes(firstShop.name))).toBe(true);
  const narrowMarkerCount = window.kakao.maps.Marker.mock.calls.length;
  window.kakao.maps.Marker.mockClear();
  fireEvent.click(screen.getByText('반경 10KM'));
  expect(window.kakao.maps.Marker.mock.calls.length).toBeGreaterThanOrEqual(narrowMarkerCount);
  expect(map.setBounds).toHaveBeenCalledTimes(2);
});

test('unsupported geolocation does not create location markers', () => {
  Object.defineProperty(navigator, 'geolocation', { configurable: true, value: undefined });
  render(<App />);
  fireEvent.click(screen.getByText('반경 1KM'));
  expect(window.kakao.maps.Marker).not.toHaveBeenCalled();
  expect(map.setBounds).not.toHaveBeenCalled();
});

test('location permission failure is handled without updating markers', () => {
  const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
  navigator.geolocation.getCurrentPosition.mockImplementation((success, failure) => failure({ code: 1 }));
  render(<App />);
  fireEvent.click(screen.getByText('반경 3KM'));
  expect(warn).toHaveBeenCalled();
  expect(window.kakao.maps.Marker).not.toHaveBeenCalled();
});

test('debounced resize updates the real map container', () => {
  jest.useFakeTimers();
  render(<App />);
  const originalWidth = window.innerWidth;
  window.innerWidth = 700;
  fireEvent(window, new Event('resize'));
  act(() => jest.advanceTimersByTime(150));
  expect(document.getElementById('map').style.width).toBe('700px');
  expect(map.relayout).toHaveBeenCalled();
  window.innerWidth = originalWidth;
});
