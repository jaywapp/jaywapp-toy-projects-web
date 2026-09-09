import Datas from "./data";

export function GetDatas(lat, lon, distance){
    var arr = new Array();

    Datas.forEach(data=>{

        var d = GetDistance(lat, lon, data.y, data.x);
        console.log('name : ' + data.name + '/' + 'distance : ' + d);

        if(d <= distance){
            console.log('▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲');
            arr.push(data);
        }
    })

    console.log(arr.length);

    return arr;
}

function GetDistance(lat1, lon1, lat2, lon2){
      
    var R = 6371; // km
    var dLat = toRad(lat2-lat1);
    var dLon = toRad(lon2-lon1);
    var lat1 = toRad(lat1);
    var lat2 = toRad(lat2);

    var sinLat = Math.sin(dLat/2);
    var sinLon = Math.sin(dLon/2);
    var a = sinLat * sinLat +
    sinLon * sinLon * Math.cos(lat1) * Math.cos(lat2);
    var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)); 
    var d = R * c;
    return d;
}

function toRad(Value) 
{
    return Value * Math.PI / 180;
}
