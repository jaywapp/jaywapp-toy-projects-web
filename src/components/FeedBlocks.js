import React, { useEffect, useState } from "react";
import { Datas, Update } from "../datas/data";

import { FeedTable, FeedGrid, Address1, Address2, AddressHeader1, AddressHeader2,
    FeedBlock, Title, Description,
    Option, Toilet, Parking, Button,
    MapDiv, MapHeader, KakaoDiv, MapDescription,
 } from "./FeedBlocks.Style";

 import Modal from "./Modal";

 const { kakao } = window;

function FeedBlocks( ){

    const [datas, setDatas] = useState([]);
    const [modalVisible, setModalVisible] = useState(false);
    const [selectedFeed, setselectedFeed] = useState(null);

    const updateCallBack = () => {
        setDatas([Datas]);
    }

    const onClick = () => {
        Update(updateCallBack)
    }
    
    const openModal = () => {
        setModalVisible(true)
    }

    const closeModal = () => {
        setModalVisible(false)
    }

    const feedClick = (item) => {
        openModal();
        setselectedFeed(item);
    }


    let index = 1;
    var data = datas[0];

    return(
        <>
            <FeedTable>
                <FeedGrid>{data && data.map((item)=> Feed(item, index++, feedClick))}</FeedGrid>
                <Button onClick={onClick}>more</Button>
            </FeedTable>
            {
                modalVisible && 
                <Modal visible={modalVisible} closable={true} maskClosable={true} onClose={closeModal}>
                    <Map item={selectedFeed}/>
                </Modal>
            }
        </>
    );
}

function Feed ( item, index, onClick ){

    let name = item['시장명'];
    let hasToilet = item['공중화장실 보유여부'];
    let hasParkingArea = item['주차장 보유여부'];
    let address_new = item['소재지도로명주소'];
    let address_old = item['소재지지번주소'];

    let columnCount = 3;

    let row = parseInt((index - 1)/ columnCount) + 1;
    let column = ((index - 1) % columnCount) + 1;

    const OnClick = () =>{
        console.log(name + ' Click');
        onClick(item);
    }

    return (
        <FeedBlock row={row} column={column} onClick={OnClick}>
            <Description>
                <Title>{name}</Title>
                <AddressHeader1>도로명</AddressHeader1>
                <AddressHeader2>번지</AddressHeader2>
                <Address1>{address_new}</Address1>
                <Address2>{address_old}</Address2>
                <Option>
                    <Toilet hasToilet={hasToilet}/>
                    <Parking hasParkingArea={hasParkingArea}/>
                </Option>
            </Description>
        </FeedBlock>
    )
}

function Map(props){

    let item = props.item;

    useEffect(() => {
        const contaier = document.getElementById('map');

        const option = {
            center: new kakao.maps.LatLng(33.450701, 126.570667),
            level: 3
        };
    
        let kakaoMap = new kakao.maps.Map(contaier, option);
        kakaoMap.setDraggable(false);    
        GetLocation(kakaoMap, item);
    }, [])

    return ( 
        <MapDiv>
            <MapHeader>{item['시장명']}</MapHeader>
            <MapDescription>{item['소재지도로명주소']}</MapDescription>
            <KakaoDiv id="map"/>
        </MapDiv> );
}

function GetLocation(kakaoMap, item)
{
    var address = item['소재지도로명주소'];
    var geocoder = new kakao.maps.services.Geocoder();

    // 주소로 좌표를 검색합니다
    geocoder.addressSearch(address, function(result, status) {
    
        // 정상적으로 검색이 완료됐으면 
         if (status === kakao.maps.services.Status.OK) {
    
            var coords = new kakao.maps.LatLng(result[0].y, result[0].x);
    
            // 결과값으로 받은 위치를 마커로 표시합니다
            var marker = new kakao.maps.Marker({
                map: kakaoMap,
                position: coords
            });
    
            // 인포윈도우로 장소에 대한 설명을 표시합니다
            var infowindow = new kakao.maps.InfoWindow({
                content: '<div style="width:150px;text-align:center;padding:6px 0;">' + item['시장명'] + '</div>'
            });
            infowindow.open(kakaoMap, marker);
    
            // 지도의 중심을 결과값으로 받은 위치로 이동시킵니다
            kakaoMap.setCenter(coords);
        } 
    });    
}

export default FeedBlocks;