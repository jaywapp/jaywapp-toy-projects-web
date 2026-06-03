import React, { useState } from 'react';
import { KakaoDiv } from '../CommonComponent';
import { GetDatas } from '../../datas/DataSelector';

const { kakao } = window;

let kakaoMap;

export function KakaoMap() {
    return ( <KakaoDiv id="map"/> )
}

export function InitializeKakaoMap(x, y){

    const contaier = document.getElementById('map');
    const option = {
        center: new kakao.maps.LatLng(x, y),
        level: 3
    };

    kakaoMap = new kakao.maps.Map(contaier, option);
}

export function ResizeKakaoMap( w, h ){

    var container = document.getElementById('map');
    
    if(container != null){
        container.style.width = w +'px';
        container.style.height = h +'px'; 

        Relayout();
    }
}

export function Pick(x, y, desc){
    var coords = new kakao.maps.LatLng(y, x);

    // 결과값으로 받은 위치를 마커로 표시합니다
    var marker = new kakao.maps.Marker({
        map: kakaoMap,
        position: coords
    });

    // 인포윈도우로 장소에 대한 설명을 표시합니다
    var infowindow = new kakao.maps.InfoWindow({
        content:  '<div style="width:150px;text-align:center;padding:6px 0;">' + desc + '</div>'
    });
    
    infowindow.open(kakaoMap, marker);
}

export function DisplayMarker(lat, lon){

    var locPosition = new kakao.maps.LatLng(lat, lon)
    // 마커를 생성합니다
    var marker = new kakao.maps.Marker({  
        map: kakaoMap, 
        position: locPosition
    }); 
    
    var iwContent = '<div style="padding:5px;color:red;">You are Here!</div>', // 인포윈도우에 표시할 내용
        iwRemoveable = true;

    // 인포윈도우를 생성합니다
    var infowindow = new kakao.maps.InfoWindow({
        content : iwContent,
        removable : iwRemoveable
    });
    
    // 인포윈도우를 마커위에 표시합니다 
    infowindow.open(kakaoMap, marker);
    
    SetCenter(locPosition);
}


export function PickAround(distance){

    if(navigator.geolocation){

        navigator.geolocation.getCurrentPosition(function(position) {
            
            var lat = position.coords.latitude;
            var lon = position.coords.longitude;

            DisplayMarker(lat, lon);

            var aroundDatas = GetDatas(lat, lon, distance);
            var points = GetPoints(lat, lon, aroundDatas);
            var bounds = GetBounds(points);

            PickDatas(aroundDatas);
            SetBounds(bounds);
        });

        console.log('fail to get current position');
    }
    else{

        console.log('Can not use geolocation on HTML5');
    }
}

function PickDatas( datas ){
    datas.forEach(data => Pick(data.x, data.y, data.name));
}

function GetBounds(points){

    var bounds = new kakao.maps.LatLngBounds();    

    var i, marker;

    for (i = 0; i < points.length; i++) {

        // 배열의 좌표들이 잘 보이게 마커를 지도에 추가합니다
        marker = new kakao.maps.Marker({ position : points[i] });
        marker.setMap(kakaoMap);
        
        // LatLngBounds 객체에 좌표를 추가합니다
        bounds.extend(points[i]);
    }

    return bounds;
}

function GetPoints( lat, lon, datas ){

    // data 좌표 수집
    var points = datas.map(data => {
        return new kakao.maps.LatLng(data.y, data.x);
    })

    // 내 좌표 수집
    points.push(new kakao.maps.LatLng(lat, lon));

    return points;
}

function SetCenter( position ){
    // 지도 중심좌표를 접속위치로 변경합니다
    kakaoMap.setCenter(position);  
}

function SetBounds( bounds ){
    kakaoMap.setBounds(bounds);
}

function Relayout(){
    kakaoMap.relayout();
}