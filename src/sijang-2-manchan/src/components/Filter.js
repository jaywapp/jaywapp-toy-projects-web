import { useState } from 'react';
import styled from 'styled-components';

const FilterDic = styled.div`
    display: grid;

`;

function Filter( { onConditionChange }) {

    // 지역, 최대거리
    // const [condition, setCondition] = useState({ type : 'Location', value : '서울', });

    return (
        <div>
        </div>
    )
}

function Filtering(target, datas){
    return datas;
}

export { Filter, Filtering };
