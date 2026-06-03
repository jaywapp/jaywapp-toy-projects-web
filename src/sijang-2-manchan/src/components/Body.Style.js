import styled from 'styled-components';
import parking from '../assets/parking.png'
import toilets from '../assets/toilets.png'

const Div = styled.div`
    text-align: center;
`;

const FlexDiv = styled.div`
     text-align: center;
`;

export function Reference(){
    return (
        <Div>
            <FlexDiv>
                <img width='20px' src={toilets}/>
                <a href="https://www.flaticon.com/free-icons/restroom" title="restroom icons">Restroom icons created by Freepik - Flaticon</a>
            </FlexDiv>
            <FlexDiv>
                <img width='20px' src={parking}/>
                <a href="https://www.flaticon.com/free-icons/parking" title="parking icons">Parking icons created by Bartama Graphic - Flaticon</a> 
            </FlexDiv>
        </Div>
    )
}