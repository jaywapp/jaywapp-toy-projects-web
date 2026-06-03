import { useState } from 'react';
import styled from 'styled-components';

const SortDic = styled.div`
    display: grid;
`;

const Header = styled.div`
`;

const RadioButton = styled.div`
    grid-column: ${(props) => props.column};
`;


function Sort( { onConditionChange }) {

    const [type, setType] = useState("Name");

    const handleClickNameRadioButton = (e) => {
        console.log("Sort ::: Name Clicked");

        setType(e.target.value);
        onConditionChange(e);
    }

    const handleClickDistanceRadioButton = (e) => {
        console.log("Sort ::: Distance Clicked");

        setType(e.target.value);
        onConditionChange(e);
    }

    return (
        <SortDic>
            <RadioButton column={1}>
                <Header>이름순</Header>
                <input type="radio" value="Name" checked={type === "Name"} onChange={handleClickNameRadioButton}/>
            </RadioButton>

            <RadioButton column={2}>
                <Header>거리순</Header>
                <input type="radio" value="Distance" checked={type === "Distance"} onChange={handleClickDistanceRadioButton}/>
            </RadioButton>
        </SortDic>
    )
}

function Sorting( type, datas ){
    if(type == "Name"){
        return datas;
    }
    else if(type == "Distance"){
        return datas;
    }
}

export { Sort, Sorting };
