import React from 'react'
import PropTypes from 'prop-types'
import styled from 'styled-components'

function Modal({ className, visible, children, onClose }) {
  return (
    <>
      <ModalOverlay visible={visible} />
      <ModalWrapper className={className} tabIndex="-1" visible={visible}>
        <ModalInner tabIndex="0" className="modal-inner">
          <ModalContent>
            <ModalChildren>
              {children}
            </ModalChildren>
            <ModalButton>
              <Button onClick={onClose}>확인</Button>
            </ModalButton>
          </ModalContent>
        </ModalInner>
      </ModalWrapper>
    </>
  )
}

Modal.propTypes = {
  visible: PropTypes.bool,
}

const Button = styled.button`
  width: 200px;
`

const ModalWrapper = styled.div`
  box-sizing: border-box;
  display: ${(props) => (props.visible ? 'block' : 'none')};
  position: fixed;
  top: 0;
  right: 0;
  bottom: 0;
  left: 0;
  z-index: 1000;
  overflow: auto;
  outline: 0;
`

const ModalOverlay = styled.div`
  box-sizing: border-box;
  display: ${(props) => (props.visible ? 'block' : 'none')};
  position: fixed;
  top: 0;
  left: 0;
  bottom: 0;
  right: 0;
  background-color: rgba(0, 0, 0, 0.6);
  z-index: 999;
`

const ModalInner = styled.div`
  box-sizing: border-box;
  position: relative;
  box-shadow: 0 0 6px 0 rgba(0, 0, 0, 0.5);
  background-color: #fff;
  border-radius: 10px;
  width: 390px;
  max-width: 480px;
  top: 50%;
  transform: translateY(-50%);
  margin: 0 auto;
  padding: 1px 20px;
`

const ModalContent = styled.div`
  display: grid;
  grid-template-rows: 1fr 100px;
`

const ModalChildren = styled.div`
  grid-row: 1;
`

const ModalButton = styled.div`
  grid-row: 2;
  margin-top: 40px;
`




export default Modal