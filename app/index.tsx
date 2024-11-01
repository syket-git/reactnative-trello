import { Colors } from "@/constants/Colors";
import { ModalType } from "@/types/enums";
import { Image, StyleSheet, Text, View } from "react-native";
import { TouchableOpacity } from "react-native-gesture-handler";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { useActionSheet } from "@expo/react-native-action-sheet";
import * as WebBrowser from "expo-web-browser";

import AuthModal from "@/components/AuthModal";
import {
  BottomSheetBackdrop,
  BottomSheetModal,
  BottomSheetModalProvider,
} from "@gorhom/bottom-sheet";
import { useCallback, useMemo, useRef, useState } from "react";

export default function Index() {
  const { top } = useSafeAreaInsets();
  const { showActionSheetWithOptions } = useActionSheet();

  const bottomSheetModalRef = useRef<BottomSheetModal>(null);

  const snapPoints = useMemo(() => ["33%"], []);
  const [authType, setAuthType] = useState<ModalType | null>(null);

  const showModal = async (type: ModalType) => {
    setAuthType(type);
    bottomSheetModalRef.current?.present();
  };

  const renderBackdrop = useCallback(
    (props: any) => (
      <BottomSheetBackdrop
        opacity={0.2}
        appearsOnIndex={0}
        disappearsOnIndex={-1}
        {...props}
      />
    ),
    []
  );

  const openLink = () => {
    WebBrowser.openBrowserAsync("https://syketb.vercel.app");
  };

  const openActionSheet = async () => {
    const options = ["View support docs", "Contact us", "Cancel"];
    const cancelButtonIndex = 2;
    showActionSheetWithOptions(
      {
        options,
        cancelButtonIndex,
        title: `Can't log in or sign up?`,
      },
      (selectedIndex: any) => {
        console.log(selectedIndex);
      }
    );
  };

  return (
    <BottomSheetModalProvider>
      <View style={[styles.container, { paddingTop: top + 30 }]}>
        <Image
          source={require("@/assets/images/login/trello.png")}
          style={styles.image}
        />
        <Text style={styles.introText}>
          Move teamwork forward - even on the go
        </Text>
        <View style={styles.bottomContainer}>
          <TouchableOpacity
            onPress={() => showModal(ModalType.Login)}
            style={[styles.btn, { backgroundColor: "#fff" }]}
          >
            <Text style={styles.btnText}>Log in</Text>
          </TouchableOpacity>

          <TouchableOpacity
            onPress={() => showModal(ModalType.SignUp)}
            style={styles.btn}
          >
            <Text style={[styles.btnText, { color: "#fff" }]}>Sign up</Text>
          </TouchableOpacity>

          <Text style={styles.description}>
            By signing up, you agree to the{" "}
            <Text onPress={openLink} style={styles.link}>
              User Notice
            </Text>{" "}
            and{" "}
            <Text onPress={openLink} style={styles.link}>
              Privacy Policy
            </Text>
            .
          </Text>
          <Text style={styles.link} onPress={openActionSheet}>
            Can't login our sign up?
          </Text>
        </View>
      </View>
      <BottomSheetModal
        index={0}
        snapPoints={snapPoints}
        ref={bottomSheetModalRef}
        handleComponent={null}
        enableOverDrag={false}
        backdropComponent={renderBackdrop}
      >
        <AuthModal type={authType} />
      </BottomSheetModal>
    </BottomSheetModalProvider>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.primary,
    alignItems: "center",
  },
  image: {
    height: 450,
    paddingHorizontal: 40,
    resizeMode: "contain",
  },
  introText: {
    fontWeight: "600",
    color: "white",
    fontSize: 17,
    padding: 30,
  },
  bottomContainer: {
    gap: 10,
    width: "100%",
    paddingHorizontal: 40,
  },
  btn: {
    padding: 10,
    borderRadius: 8,
    alignItems: "center",
    borderColor: "#fff",
    borderWidth: 1,
  },
  btnText: {
    fontSize: 18,
  },

  description: {
    fontSize: 12,
    textAlign: "center",
    color: "#fff",
    marginHorizontal: 60,
  },
  link: {
    color: "#fff",
    fontSize: 12,
    textAlign: "center",
    textDecorationLine: "underline",
  },
});
