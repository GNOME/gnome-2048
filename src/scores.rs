/*
 * Copyright 2025 Andrey Kutejko <andy128k@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see <http://www.gnu.org/licenses/>.
 *
 * For more details see the file COPYING.
 */

use crate::grid::GridSize;
use async_channel::Sender;
use gettextrs::{gettext, pgettext};
use gtk::{
    ffi::GtkWindow,
    gio::ffi::{GAsyncReadyCallback, GAsyncResult, GCancellable},
    glib::{
        self,
        ffi::{GError, GType, gboolean, gpointer},
        gobject_ffi::GObject,
        translate::{ToGlibPtr, from_glib, from_glib_full, from_glib_none},
    },
    prelude::*,
};
use std::{error::Error, ffi::c_char, rc::Rc};

mod ffi {
    use super::*;

    type CategoryRequestFunc =
        unsafe extern "C" fn(category_name: *const c_char, user_data: gpointer) -> *mut GObject;

    unsafe extern "C" {
        pub unsafe fn games_scores_context_get_type() -> GType;
        pub unsafe fn games_scores_context_load_scores(
            context: *mut GObject,
            category_request: CategoryRequestFunc,
            user_data: gpointer,
            error: *mut *mut GError,
        );
        pub unsafe fn games_scores_context_present_dialog(
            context: *mut GObject,
            window: *mut GtkWindow,
            category: *mut GObject,
        );
        pub unsafe fn games_scores_context_add_score(
            context: *mut GObject,
            score: i64,
            category: *mut GObject,
            game_window: *mut GtkWindow,
            cancellable: *mut GCancellable,
            callback: GAsyncReadyCallback,
            user_data: gpointer,
        );
        pub unsafe fn games_scores_context_add_score_finish(
            context: *mut GObject,
            res: *mut GAsyncResult,
            error: *mut *mut GError,
        ) -> gboolean;

        pub unsafe fn games_scores_style_get_type() -> GType;
        pub unsafe fn games_scores_category_get_type() -> GType;
    }
}

pub struct Scores {
    context: glib::Object,
    grid3_category: glib::Object,
    grid4_category: glib::Object,
    grid5_category: glib::Object,
}

impl Scores {
    pub fn new() -> Rc<Self> {
        let grid3_category = create_category("grid3", &pgettext("Scores category", "Grid 3 × 3"));
        let grid4_category = create_category("grid4", &pgettext("Scores category", "Grid 4 × 4"));
        let grid5_category = create_category("grid5", &pgettext("Scores category", "Grid 5 × 5"));

        let this = Rc::new(Self {
            grid3_category,
            grid4_category,
            grid5_category,
            context: create_context(),
        });

        context_load_scores(&this.context, &this);

        this
    }

    pub fn present_dialog(&self, parent_window: &impl IsA<gtk::Window>) {
        // TODO open it for current Scores.Category
        unsafe {
            ffi::games_scores_context_present_dialog(
                self.context.to_glib_none().0,
                parent_window.as_ref().to_glib_none().0,
                std::ptr::null_mut(),
            );
        }
    }

    pub async fn show_best_scores(
        &self,
        size: GridSize,
        score: i64,
        parent_window: &impl IsA<gtk::Window>,
    ) {
        if !size.is_predefined() {
            // FIXME add categories for non-square grids
            return;
        }
        let category = match size.cols() {
            3 => &self.grid3_category,
            4 => &self.grid4_category,
            5 => &self.grid5_category,
            _ => return, // FIXME add categories for non-usual square grids
        };
        match context_add_score(&self.context, category, score, parent_window).await {
            Ok(_) => {}
            Err(error) => {
                eprintln!("{error}")
            }
        }
        self.present_dialog(parent_window);
    }
}

fn create_context() -> glib::Object {
    let context_type: glib::Type = unsafe { from_glib(ffi::games_scores_context_get_type()) };
    glib::Object::builder_with_type(context_type)
        .property("app-name", "gnome-2048")
        .property("icon-name", "org.gnome.TwentyFortyEight")
        .property("category-type", gettext("Grid Size"))
        .property("style", create_style("points-greater-is-better"))
        .property("max-high-scores", 10)
        .build()
}

fn context_load_scores(context: &glib::Object, scores: &Rc<Scores>) {
    unsafe extern "C" fn category_request(
        category_name: *const c_char,
        user_data: gpointer,
    ) -> *mut GObject {
        let category_name: String = unsafe { from_glib_none(category_name) };
        let scores: &Rc<Scores> = unsafe { &*(user_data as *const Rc<Scores>) };
        match category_name.as_str() {
            "grid3" => scores.grid3_category.to_glib_none().0,
            "grid4" => scores.grid4_category.to_glib_none().0,
            "grid5" => scores.grid5_category.to_glib_none().0,
            _ => std::ptr::null_mut(),
        }
    }

    let mut error: *mut GError = std::ptr::null_mut();
    let user_data: Box<Rc<Scores>> = Box::new(scores.clone());
    unsafe {
        ffi::games_scores_context_load_scores(
            context.to_glib_none().0,
            category_request,
            Box::into_raw(user_data) as *mut _,
            &mut error,
        );
    }
}

async fn context_add_score(
    context: &glib::Object,
    category: &glib::Object,
    score: i64,
    parent_window: &impl IsA<gtk::Window>,
) -> Result<bool, Box<dyn Error>> {
    unsafe extern "C" fn callback(
        context: *mut GObject,
        result: *mut GAsyncResult,
        user_data: gpointer,
    ) {
        let sender: Box<Sender<Result<bool, glib::Error>>> =
            unsafe { Box::from_raw(user_data as *mut _) };
        let mut error: *mut GError = std::ptr::null_mut();
        let added =
            unsafe { ffi::games_scores_context_add_score_finish(context, result, &mut error) };
        let channel_result = if error.is_null() {
            sender.send_blocking(Ok(added != 0))
        } else {
            let error: glib::Error = unsafe { from_glib_full(error) };
            sender.send_blocking(Err(error))
        };
        if let Err(channel_error) = channel_result {
            eprintln!("Channel error: {channel_error}");
        }
    }

    let (sender, receiver) = async_channel::bounded(1);
    let user_data: Box<Sender<Result<bool, glib::Error>>> = Box::new(sender);
    unsafe {
        ffi::games_scores_context_add_score(
            context.to_glib_none().0,
            score,
            category.to_glib_none().0,
            parent_window.as_ref().to_glib_none().0,
            std::ptr::null_mut(),
            Some(callback),
            Box::into_raw(user_data) as *mut _,
        )
    }

    match receiver.recv().await {
        Ok(Ok(result)) => Ok(result),
        Ok(Err(error)) => Err(error.into()),
        Err(error) => Err(error.into()),
    }
}

fn create_style(value: &str) -> glib::Value {
    let style_type: glib::Type = unsafe { from_glib(ffi::games_scores_style_get_type()) };
    let style_class = glib::EnumClass::with_type(style_type).unwrap();
    style_class.to_value_by_nick(value).unwrap()
}

fn create_category(key: &str, name: &str) -> glib::Object {
    let category_type: glib::Type = unsafe { from_glib(ffi::games_scores_category_get_type()) };
    glib::Object::builder_with_type(category_type)
        .property("key", key)
        .property("name", name)
        .build()
}
